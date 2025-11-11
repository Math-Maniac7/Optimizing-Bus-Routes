#pragma once
#include "../defs.h"
#include "../config.h"
#if _ISWASM
    #include <emscripten/fetch.h>
#else
    #include <curl/curl.h>
#endif

#include <string>
#include <vector>
#include <stdexcept>

struct HttpResponse {
    long status = 0;                     // HTTP status code
    std::string body;                    // response body
    std::vector<std::string> headers;    // raw response headers
    std::string effective_url;           // URL after redirects
    bool exists = false;
};

// simple HTTP client using libcurl
// - method                     : "GET", "POST", "PUT", "PATCH", "DELETE", ...
// - body                       : optional request body string
// - headers                    : each in format "name: value"
// - timeout/connect_timeout    : seconds
HttpResponse http_request(
    const std::string& url,
    const std::string& method = "GET",
    const std::string& body = "",
    const std::vector<std::string>& headers = {},
    long timeout = 60,
    long connect_timeout = 10,
    bool follow_redirects = true,
    const char* user_agent = "cpp-libcurl/1.0"
);

std::string url_encode(const std::string& s);

HttpResponse http_request_retry(
    const std::string& url,
    const std::string& method = "GET",
    const std::string& body = "",
    const std::vector<std::string>& headers = {},
    long timeout = 60,
    long connect_timeout = 10,
    bool follow_redirects = true,
    const char* user_agent = "cpp-libcurl/1.0",
    const std::vector<int> retry_status = {},
    const int retry_count = 5
);
