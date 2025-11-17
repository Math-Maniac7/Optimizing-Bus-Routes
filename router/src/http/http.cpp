#include "http.h"
#include <iostream>

/*
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
*/

#if _ISWASM
#include <emscripten/fetch.h>

//Download and succeed based on the examples
void downloadSucceeded(emscripten_fetch_t *fetch) {
    //Bit of stack overflow, vibecoding, reading the docs, and tears
    // Ensure fetch is valid
    if (!fetch) return;
    // Initialize response struct
    HttpResponse* resp = static_cast<HttpResponse*>(fetch->userData);
    if (!resp) return;
    // Set status code
    resp->status = fetch->status;
    // Set response body
    resp->body.assign(fetch->data, fetch->numBytes);
    // Set effective URL (after redirects)
    resp->effective_url = fetch->url;
    // Initialize headers vector
    resp->headers.clear();
    // Get headers length
    size_t headersLength = emscripten_fetch_get_response_headers_length(fetch);
    if (headersLength > 0) {
        // Allocate buffer for headers
        std::vector<char> headersBuffer(headersLength + 1);
        emscripten_fetch_get_response_headers(fetch, headersBuffer.data(), headersLength + 1);

        // Parse headers into key-value pairs
        char** unpackedHeaders = emscripten_fetch_unpack_response_headers(headersBuffer.data());
        if (unpackedHeaders) {
            for (size_t i = 0; unpackedHeaders[i] != nullptr; i += 2) {
                resp->headers.emplace_back(unpackedHeaders[i]);
                resp->headers.emplace_back(unpackedHeaders[i + 1]);
            }
            // Free unpacked headers
            emscripten_fetch_free_unpacked_response_headers(unpackedHeaders);
        }
    }
    // Mark response as existing
    resp->exists = true;
    *((HttpResponse*)fetch->userData) = *resp;
    // Close fetch
    emscripten_fetch_close(fetch);
}

void downloadFailed(emscripten_fetch_t *fetch) {
  printf("Downloading %s failed, HTTP status code: %d.\n",
         fetch->url, fetch->status);
    static_cast<HttpResponse*>(fetch->userData)->exists = true;


  emscripten_fetch_close(fetch);
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
    emscripten_fetch_attr_t attr;
    emscripten_fetch_attr_init(&attr);

    // Set method
    strncpy(attr.requestMethod, method.c_str(), sizeof(attr.requestMethod)-1);
    attr.requestMethod[sizeof(attr.requestMethod)-1] = '\0';

    attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY;

    //These functions are called on success or fail
    attr.onsuccess = downloadSucceeded;
    attr.onerror   = downloadFailed;

    //Response goes here
    HttpResponse resp;
    resp.exists = false;
    attr.userData = &resp;

    // Set request headers
    if (!headers.empty()) {
        // Copy header strings into a separate vector to keep them alive
        static std::vector<std::string> header_storage; 
        header_storage = headers; // copy input headers

        // Convert to const char* array
        static std::vector<const char*> hdr_ptrs;
        hdr_ptrs.clear();
        for (const auto &h : header_storage) {
            if (!h.empty() && h.find(':') != std::string::npos) {
                auto pos {h.find(':')};
                char* left {(char*)malloc(pos+1)};
                memcpy(left, h.c_str(), pos);
                left[pos] = '\0';
                for (auto i{int(0)}; i < pos; i++){
                    if (left[i] == ' ')
                        left[i] = '\0';
                }

                char* right {(char*)malloc(h.size() - pos)};
                memcpy(right, h.c_str() + pos + 1, h.size()-pos);

                //hdr_ptrs.push_back(h.c_str()); // safe pointer
               // hdr_ptrs.push_back(h.c_str()+ h.find(':'));
               hdr_ptrs.push_back(left);
               hdr_ptrs.push_back(right);
            } else {
                std::cerr << "Invalid header skipped: " << h << std::endl;
            }
        }
    }

    if (!body.empty()) {
        attr.requestData = (char*)body.c_str();
        attr.requestDataSize = body.size();
    }

    //Actually fetch
    emscripten_fetch(&attr, url.c_str());       

    //wait for response
    while (resp.exists == false){emscripten_sleep(10);}

    

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

/*
int main() {
    // Define the URL and other parameters
    std::string url = "https://jsonplaceholder.typicode.com/posts/1";
    std::string method = "GET";
    std::string body = "";
    std::vector<std::string> headers = {"User-Agent: MyHttpClient"};
    long timeout = 5000; // Timeout in milliseconds
    long connect_timeout = 1000; // Connect timeout in milliseconds
    bool follow_redirects = true;
    const char* user_agent = "MyHttpClient";

    // Call the http_request function
    HttpResponse response = http_request(url, method, body, headers, timeout, connect_timeout, follow_redirects, user_agent);

    // Check if the request was successful
    if (response.exists) {
        std::cout << "Status: " << response.status << std::endl;
        std::cout << "Body: " << response.body.substr(0, 200) << "..." << std::endl; // Print first 200 chars of body
        std::cout << "Effective URL: " << response.effective_url << std::endl;
        std::cout << "Headers: ";
        for (const auto& header : response.headers) {
            std::cout << header << " ";
        }
        std::cout << std::endl;
    } else {
        std::cerr << "Request failed." << std::endl;
    }

    return 0;
}*/

#else
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

#endif

HttpResponse http_request_retry(
    const std::string& url,
    const std::string& method,
    const std::string& body,
    const std::vector<std::string>& headers,
    long timeout,
    long connect_timeout,
    bool follow_redirects,
    const char* user_agent,
    const std::vector<int> retry_status,
    const int retry_count
) {
    HttpResponse res;
    for(int i = 0; i < retry_count; i++) {
        res = http_request(url, method, body, headers, timeout, connect_timeout, follow_redirects, user_agent);
        for(int s : retry_status) if(res.status == s) {
            std::cout << "Retrying HTTP request : " << method << " " << url << " " << (i + 1) << "/" << retry_count << "\n";
            goto retry;
        }
        break;
        retry: {}
    }
    return res;
}