const routeModules = new Map([
  ["/api/nido/legal/privacy", () => import("../../app/api/nido/legal/privacy/route.ts")],
  ["/api/nido/legal/support", () => import("../../app/api/nido/legal/support/route.ts")],
]);

export async function requestLegalPage(pathname, init = {}) {
  const loadRoute = routeModules.get(pathname);
  if (!loadRoute) return new Response("Not Found", { status: 404 });
  let route;
  try {
    route = await loadRoute();
  } catch (error) {
    if (error?.code === "ERR_MODULE_NOT_FOUND") return new Response("Not Found", { status: 404 });
    throw error;
  }
  const request = init instanceof Request
    ? init
    : new Request(new URL(pathname, "https://nido.test"), init);
  return route.GET(request);
}
