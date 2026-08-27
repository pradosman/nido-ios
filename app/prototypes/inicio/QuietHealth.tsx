"use client";

import { useState } from "react";
import { Bottle, ChevronRight, Clock3, Drops, HeartPulse, MoonSleep, Plus } from "reicon-react";

export default function QuietHealth() {
  const [sleeping, setSleeping] = useState(false);
  const [notice, setNotice] = useState("");
  const register = (label: string) => {
    setNotice(`${label} registrado ahora`);
    window.setTimeout(() => setNotice(""), 1800);
  };

  return <section className="quiet-shell">
    <header className="quiet-header"><div><span>Jueves, 27 de agosto</span><h1>Marco</h1><p>Recién nacido · Hoy</p></div><button aria-label="Añadir registro"><Plus weight="Filled" /></button></header>
    <div className="quiet-actions" aria-label="Registro rápido">
      <button onClick={() => setSleeping(!sleeping)}><i className="quiet-sleep"><MoonSleep weight="Filled" /></i><span>Sueño</span></button>
      <button onClick={() => register("Toma")}><i className="quiet-feed"><Bottle weight="Filled" /></i><span>Toma</span></button>
      <button onClick={() => register("Pañal")}><i className="quiet-diaper"><Drops weight="Filled" /></i><span>Pañal</span></button>
      <button onClick={() => register("Cuidado")}><i className="quiet-care"><HeartPulse weight="Filled" /></i><span>Cuidado</span></button>
    </div>
    <section className="quiet-group">
      <h2>Ahora</h2>
      <button className="quiet-focus" onClick={() => setSleeping(!sleeping)}>
        <span className="quiet-focus-icon">{sleeping ? <Clock3 weight="Filled" /> : <MoonSleep weight="Filled" />}</span>
        <span><small>{sleeping ? "Sueño en curso" : "Siguiente paso"}</small><strong>{sleeping ? "00:12" : "Registrar el primer sueño"}</strong><em>{sleeping ? "Toca para terminar y guardar" : "Aprenderemos su ritmo con cada registro"}</em></span>
        <ChevronRight />
      </button>
    </section>
    <section className="quiet-group">
      <h2>Resumen de hoy</h2>
      <div className="quiet-list">
        <div><span><MoonSleep />Sueño</span><strong>0 min</strong></div>
        <div><span><Bottle />Tomas</span><strong>0</strong></div>
        <div><span><Drops />Pañales</span><strong>0</strong></div>
      </div>
    </section>
    <section className="quiet-group">
      <h2>Actividad</h2>
      <div className="quiet-empty"><Clock3 /><strong>El día empieza aquí</strong><p>Los registros aparecerán en orden, sin ruido ni datos de ejemplo.</p></div>
    </section>
    {notice && <div className="prototype-toast" role="status">{notice}</div>}
  </section>;
}
