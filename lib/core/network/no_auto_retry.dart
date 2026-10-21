/// Disables Riverpod's automatic retry of failed providers.
///
/// Riverpod 3 retries a throwing provider up to 10 times by default. For
/// providers backed by BOT that would turn one 403 into a burst of calls
/// against a 200/hour quota. Transient errors are already retried, once
/// and selectively, by `RetryInterceptor`; everything else waits for the
/// user (retry button, pull-to-refresh).
Duration? noAutoRetry(int retryCount, Object error) => null;
