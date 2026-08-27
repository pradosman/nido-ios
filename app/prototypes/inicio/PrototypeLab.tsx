"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import QuietHealth from "./QuietHealth";
import FamilyJournal from "./FamilyJournal";
import SpatialHome from "./SpatialHome";

const variants = [
  { name: "Quiet Health", component: QuietHealth },
  { name: "Family Journal", component: FamilyJournal },
  { name: "Spatial Home", component: SpatialHome },
] as const;

export default function PrototypeLab() {
  const [current, setCurrent] = useState(0);
  const [replay, setReplay] = useState(0);
  const pickerRef = useRef<HTMLElement>(null);
  const highlightRef = useRef<HTMLSpanElement>(null);
  const itemRefs = useRef<Array<HTMLButtonElement | null>>([]);

  const moveHighlight = useCallback(() => {
    const item = itemRefs.current[current];
    const highlight = highlightRef.current;
    if (!item || !highlight) return;
    highlight.style.width = `${item.offsetWidth}px`;
    highlight.style.transform = `translateX(${item.offsetLeft}px)`;
  }, [current]);

  const choose = useCallback((index: number) => {
    if (index < 0 || index >= variants.length) return;
    setCurrent(index);
    setReplay((value) => value + 1);
    const url = new URL(window.location.href);
    url.searchParams.set("v", String(index + 1));
    window.history.replaceState(null, "", url);
  }, []);

  useEffect(() => {
    const requested = Number(new URLSearchParams(window.location.search).get("v")) || 1;
    const syncSelection = window.setTimeout(() => setCurrent(Math.min(variants.length - 1, Math.max(0, requested - 1))), 0);
    const ready = window.requestAnimationFrame(() => window.requestAnimationFrame(() => pickerRef.current?.setAttribute("data-ready", "")));
    return () => {
      window.clearTimeout(syncSelection);
      window.cancelAnimationFrame(ready);
    };
  }, []);

  useLayoutEffect(() => {
    moveHighlight();
  }, [moveHighlight]);

  useEffect(() => {
    const resize = () => moveHighlight();
    const keydown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement;
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName) || target.isContentEditable) return;
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      const number = Number.parseInt(event.key, 10);
      if (number >= 1 && number <= variants.length) choose(number - 1);
      else if (event.key === "ArrowRight") choose((current + 1) % variants.length);
      else if (event.key === "ArrowLeft") choose((current - 1 + variants.length) % variants.length);
      else if (event.key === "r" || event.key === "R") setReplay((value) => value + 1);
    };
    window.addEventListener("resize", resize);
    document.addEventListener("keydown", keydown);
    return () => {
      window.removeEventListener("resize", resize);
      document.removeEventListener("keydown", keydown);
    };
  }, [choose, current, moveHighlight]);

  const Variant = variants[current].component;
  return (
    <main className="proto-stage">
      <Variant key={`${current}-${replay}`} />
      <nav className="proto-picker" aria-label="Prototype variants" data-position="top" ref={pickerRef}>
        <span className="proto-picker-highlight" aria-hidden="true" ref={highlightRef}></span>
        {variants.map((variant, index) => (
          <button
            key={variant.name}
            className="proto-picker-item"
            data-active={current === index ? "" : undefined}
            aria-current={current === index ? "true" : undefined}
            onClick={() => choose(index)}
            ref={(node) => { itemRefs.current[index] = node; }}
          >
            {variant.name}
          </button>
        ))}
        <span className="proto-picker-divider" aria-hidden="true"></span>
        <button className="proto-picker-item proto-picker-replay" aria-label="Replay animation (R)" onClick={() => setReplay((value) => value + 1)}>↻</button>
      </nav>
    </main>
  );
}
