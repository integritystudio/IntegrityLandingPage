/// HTTP status codes used by service layer.
enum HttpStatus {
  ok(200),
  forbidden(403),
  tooManyRequests(429),
  gatewayTimeout(504);

  const HttpStatus(this.code);
  final int code;
}
