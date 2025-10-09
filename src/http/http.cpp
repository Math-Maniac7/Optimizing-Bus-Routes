#include "http.h"

size_t write_body_cb(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* out = static_cast<std::string*>(userdata);
    out->append(ptr, size * nmemb);
    return size * nmemb;
}
size_t write_hdr_cb(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* out = static_cast<std::vector<std::string>*>(userdata);
    const size_t n = size * nmemb;
    // split incoming header chunk by '\n' (libcurl may call multiple times)
    std::string line(ptr, n);
    // normalize line endings; keep as-is if no CRLF
    if (!line.empty() && (line.back() == '\n' || line.back() == '\r')) {
        while (!line.empty() && (line.back() == '\n' || line.back() == '\r')) line.pop_back();
    }
    if (!line.empty()) out->push_back(std::move(line));
    return n;
}

HttpResponse http_request(
    const std::string& url,
    const std::string& method,
    const std::string& body,
    const std::vector<std::string>& headers,
    long timeout,
    long connect_timeout,
    bool follow_redirects,
    const char* user_agent
) {
    CURLcode rc;
    HttpResponse resp;
    char errbuf[CURL_ERROR_SIZE] = {0};

    static bool curl_inited = false;
    if (!curl_inited) {
        rc = curl_global_init(CURL_GLOBAL_DEFAULT);
        if (rc != CURLE_OK) throw std::runtime_error("curl_global_init failed");
        curl_inited = true;
    }

    CURL* curl = curl_easy_init();
    if (!curl) throw std::runtime_error("curl_easy_init failed");

    // Build header list
    struct curl_slist* hdrs = nullptr;
    for (const auto& h : headers) hdrs = curl_slist_append(hdrs, h.c_str());

    // Method configuration
    if (method == "GET") {
        curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
    } else if (method == "POST") {
        curl_easy_setopt(curl, CURLOPT_POST, 1L);
    } else {
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method.c_str());
    }

    if (!body.empty()) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
        // Optional: if body may contain NULs, use POSTFIELDSIZE instead:
        // curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(body.size()));
    }

    // Core options
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_body_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &resp.body);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, write_hdr_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &resp.headers);
    curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errbuf);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, user_agent);
    curl_easy_setopt(curl, CURLOPT_ACCEPT_ENCODING, ""); // enable gzip/deflate if server supports
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, follow_redirects ? 1L : 0L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, connect_timeout);

    // (TLS verification is ON by default; leave it that way for production)

    rc = curl_easy_perform(curl);

    if (rc == CURLE_OK) {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &resp.status);
        char* eff = nullptr;
        if (curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &eff) == CURLE_OK && eff) {
            resp.effective_url = eff;
        }
    }

    curl_slist_free_all(hdrs);
    curl_easy_cleanup(curl);

    if (rc != CURLE_OK) {
        std::string msg = "curl error: ";
        msg += (errbuf[0] ? errbuf : curl_easy_strerror(rc));
        throw std::runtime_error(msg);
    }

    return resp;
}

std::string url_encode(const std::string& s) {
    std::string out; out.reserve(s.size()*3);
    auto is_unreserved = [](unsigned char c){
        return std::isalnum(c) || c=='-' || c=='_' || c=='.' || c=='~';
    };
    char buf[4];
    for (unsigned char c : s) {
        if (is_unreserved(c)) out.push_back(c);
        else { std::snprintf(buf, sizeof(buf), "%%%.2X", c); out += buf; }
    }
    return out;
}