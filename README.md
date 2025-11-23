# OWASP CRS - Traffic Oberservation Plugin

This is an offical CRS plugin that logs information about requests that is not normally logged.

We are planning to do performance testing. But that depends on real world sample traffic. Now the problem is
there is relatively little litterature on representative HTTP traffic.

More information about this idea: https://github.com/coreruleset/coreruleset/wiki/Dev-Retreat-2025-Sample-Traffic

This plugin writes down this information with the idea to bring up this information.

As is, the plugin writes a single log message (non-blocking alert) per request.

Information we are interested in:

* HTTP protocol version
* HTTP Method
* URI
* Query string parameters
* Request body
* Request body content type: urlencoded, XML, JSON
* HTTP request headers, special handling of User-Agent and Referer
* HTTP request cookies
* HTTP response status code
* HTTP response headers
* HTTP response body
* HTTP response body content type
* Session characteristics (number, order and rhythm of requests, etc. - we're probably ignoring this)
* HTTP/2 and 3 specific characteristics like number of streams and the like, but that is not accessible for ModSec right now

## Installation

Put the contents of the `plugin` folder into your installation's CRS4 `plugin` folder. The plugin is active by default.

## Simple Analysis

The plugin writes it's messages as JSON. Well almost as JSON. ModSec does not 
allow double quotes in the log messages, so we write single quotes and we need to translate that into
double quotes before we can work on the data.

The alias `meldata` is part of a larger collection of useful ModSecurity aliases hosted together with a lot of tutorials at [netnea.com)(https://netnea.com). This is also where you can find the `basicstats.awk` script.

```bash
$ alias meldata='grep -o "\[data [^]]*" | cut -d\" -f2'
$ grep 9526200 error.log | tail -1
[2025-11-23 23:38:44.665603] [security2:error] 217.113.196.248:30561 aSOM9KWBJ_OKwMQcydUBEAAAAAo ModSecurity: Warning. Unconditional match in SecAction. [file "/etc/apache2/crs/plugins/traffic-observation-after.conf"] [line "100"] [id "9526200"] [msg "Logging traffic-observation-plugin data"] [data "{ 'Protocol' : 'HTTP/1.1', 'Method' : 'GET', 'LenFilename' : '10', 'LenQueryString' : '', 'NumQueryStringArgs' : '0', 'NumReqHeaders' : '6', 'LenCookies' : '', 'NumCookies' : '0', 'ReqContentType' : '', 'ReqContentLength' : '', 'StatusCode' : '200', 'NumRespHeaders' : '15', 'RespContentType' : 'application/rss+xml', 'RespContentLength' : '1479'}"] [ver "traffic-observation-plugin/1.0.0"] [tag "traffic-observation"] [hostname "www.netnea.com"] [uri "/index.php"] [unique_id "aSOM9KWBJ_OKwMQcydUBEAAAAAo"]
$ grep 9526200 error.log | meldata | tr "'" "\"" | tail -1 | jq
{
  "Protocol": "HTTP/1.1",
  "Method": "GET",
  "LenFilename": "54",
  "LenQueryString": "",
  "NumQueryStringArgs": "0",
  "NumReqHeaders": "3",
  "LenCookies": "",
  "NumCookies": "0",
  "ReqContentType": "",
  "ReqContentLength": "",
  "StatusCode": "200",
  "NumRespHeaders": "9",
  "RespContentType": "text/html",
  "RespContentLength": "3887"
}
$ grep 9526200 error.log | meldata | tr "'" "\"" | jq -r .NumReqHeaders | ~/bin/basicstats.awk 
Num of values:             301.00
         Mean:               7.88
       Median:               6.00
          Min:               2.00
          Max:              16.00
        Range:              14.00
Std deviation:               3.64
```


## License

Copyright (c) 2021-2025 OWASP CRS project. All rights reserved.

The OWASP CRS and its official plugins are
distributed under Apache Software License (ASL) version 2.
Please see the enclosed LICENSE file for full details.
