"use client";

import { useState } from "react";
import { Bottle, Clock3, Drops, HeartPulse, MoonSleep, Plus, Sparkles } from "reicon-react";

export default function SpatialHome() {
  const [sleeping, setSleeping] = useState(false);
  const [last, setLast] = useState("Sin actividad todavía");
  const register = (value: string) => setLast(`${value} · ahora`);

  return <section className="spatial-shell">
    <header className="spatial-header"><div><span>Nido · Marco</span><h1>Buenos días, David</h1></div><button aria-label="Añadir"><Plus weight="Filled" /></button></header>
    <main className="spatial-grid">
      <button className={`spatial-tile spatial-sleep ${sleeping ? "active" : ""}`} onClick={() => setSleeping(!sleeping)}>
        <span className="spatial-symbol"><MoonSleep weight="Filled" /></span>
        <span className="spatial-copy"><small>{sleeping ? "Durmiendo ahora" : "Sueño"}</small><strong>{sleeping ? "00:12" : "Empezar temporizador"}</strong></span>
        <em>{sleeping ? "Terminar" : "Iniciar"}</em>
      </button>
      <button className="spatial-tile spatial-feed" onClick={() => register("Toma")}><span className="spatial-symbol"><Bottle weight="Filled" /></span><span className="spatial-copy"><small>Toma</small><strong>Registrar</strong></span></button>
      <button className="spatial-tile spatial-diaper" onClick={() => register("Pañal")}><span className="spatial-symbol"><Drops weight="Filled" /></span><span className="spatial-copy"><small>Pañal</small><strong>Registrar</strong></span></button>
      <button className="spatial-tile spatial-care" onClick={() => register("Cuidado")}><span className="spatial-symbol"><HeartPulse weight="Filled" /></span><span className="spatial-copy"><small>Cuidado</small><strong>Añadir</strong></span></button>
      <section className="spatial-tile spatial-day"><div><Clock3 /><span><small>Último registro</small><strong>{last}</strong></span></div><p>Hoy empieza vacío. Nido irá componiendo el día a medida que ocurre.</p></section>
      <section className="spatial-tile spatial-insight"><Sparkles weight="Filled" /><div><small>Aprendiendo</small><strong>3 sueños para empezar a reconocer su ritmo.</strong></div></section>
    </main>
  </section>;
}
