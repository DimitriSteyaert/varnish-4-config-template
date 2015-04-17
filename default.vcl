vcl 4.0;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

acl purgers {
    "localhost";
    "127.0.0.1";
}

sub vcl_recv {

    # Allow purging
    if (req.method == "PURGE") {
      if (!client.ip ~ purgers) {
        return (synth(405, "This IP is not allowed to send PURGE requests."));
      }
      return (purge);
    }

    # Set proxied ip header to original remote address
    unset req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = client.ip;

    # Remove has_js and Google Analytics cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(__[a-z]+|__utm*|has_js)=[^;]*", "");

    # Remove a ";" prefix, if present.
    set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");

    # Remove empty cookies.
    if (req.http.Cookie ~ "^\s*$") {
            unset req.http.Cookie;
    }

    # remove double // in urls,
        set req.url = regsuball( req.url, "//", "/"      );

    # Normalize Accept-Encoding
    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
            # No point in compressing these
            unset req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unknown algorithm
            unset req.http.Accept-Encoding;
        }
    }

    # Remove cookies for static files
    if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png|tif|tiff|mp3|htm|html|md5)(\?.*|)$") {
        unset req.http.cookie;
        return(hash);
    }

    # Disable caching for backend parts
    if ( req.url ~ "^/(admin|login)" ) {
        return(pass);
    }

    # Strip cookies for cached content
    unset req.http.Cookie;
    return(hash);

}

sub vcl_backend_response {

    # If the backend fails, keep serving out of the cache for 30m
    set beresp.grace = 30m;
    set beresp.ttl = 48h;

    # Remove some unwanted headers
    unset beresp.http.Server;
    unset beresp.http.X-Powered-By;

    # Respect the Cache-Control=private header from the backend
    if (beresp.http.Cache-Control ~ "private") {
        set beresp.http.X-Cacheable = "NO:Cache-Control=private";
    } elsif (beresp.ttl < 1s) {
        set beresp.ttl   = 120s;
        set beresp.grace = 5s;
        set beresp.http.X-Cacheable = "YES:FORCED";
    } else {
        set beresp.http.X-Cacheable = "YES";
    }

    # Don't cache responses to posted requests or requests with basic auth
    if ( bereq.method == "POST" || bereq.http.Authorization ) {
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return (deliver);
    }

    # Cache error pages for a short while
    if( beresp.status == 404 || beresp.status == 500 || beresp.status == 301 || beresp.status == 302 ){
        set beresp.ttl = 1m;
        return(deliver);
    }

    # Do not cache non-success response
    if( beresp.status != 200 ){
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return(deliver);
    }

    # Strip cookies before these filetypes are inserted into the cache
    if (bereq.url ~ "\.(png|gif|jpg|swf|css|js)(\?.*|)$") {
        unset beresp.http.set-cookie;
    }

    return(deliver);

}

sub vcl_deliver {

    # Add debugging headers to cache requests
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    }
    else {
        set resp.http.X-Cache = "MISS";
    }
}

sub vcl_purge {
    # Only handle actual PURGE requests, all the rest is discarded
    if (req.method != "PURGE") {
        # restart request
        set req.http.X-Purge = "Yes";
        return(restart);
    }
}
