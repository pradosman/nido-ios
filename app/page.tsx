import NidoApp from "./NidoApp";
import type { Metadata } from "next";
import { headers } from "next/headers";

export async function generateMetadata(): Promise<Metadata> {
  const headerStore = await headers();
  const host = headerStore.get("host") ?? "localhost:3000";
  const protocol = headerStore.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const image = `${protocol}://${host}/og.png`;
  const title = "Nido — El día de tu bebé";
  const description = "El cuidado de tu bebé, claro y compartido.";

  return {
    title,
    description,
    openGraph: { title, description, images: [{ url: image, width: 1792, height: 932, alt: "Nido, el cuidado de tu bebé" }] },
    twitter: { card: "summary_large_image", title, description, images: [image] },
  };
}

export default function Home() {
  return <NidoApp />;
}
