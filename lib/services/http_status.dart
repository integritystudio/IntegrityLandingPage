/// HTTP status codes used by service layer.
enum HttpStatus {
  ok(200),
  unauthorized(401),
  forbidden(403),
  notFound(404),
  conflict(409),
  tooManyRequests(429),
  internalServerError(500),
  serviceUnavailable(503),
  gatewayTimeout(504);

  const HttpStatus(this.code);
  final int code;
}
