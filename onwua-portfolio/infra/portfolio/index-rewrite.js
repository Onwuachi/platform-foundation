function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // If the URI ends with a slash, append index.html
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    // If the URI has no file extension (no dot in the last segment),
    // treat it as a directory and append /index.html
    else if (!uri.includes('.', uri.lastIndexOf('/'))) {
        request.uri += '/index.html';
    }

    return request;
}
