function runtimeValue(name: string) {
  return process.env[name]?.trim() || null;
}

export function appleAudience() {
  return runtimeValue("NIDO_APPLE_AUDIENCE");
}

export function authBucketSecret() {
  const value = runtimeValue("NIDO_AUTH_BUCKET_SECRET");
  return value && value.length >= 32 ? value : null;
}
