import { legalPageResponse } from "../legal-pages.ts";

export function GET() {
  return legalPageResponse("support");
}
