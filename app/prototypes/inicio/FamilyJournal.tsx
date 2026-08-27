"use client";

import { useState } from "react";
import { CareSymbol, DiaperSymbol, FeedSymbol, MomentSymbol, NidoMark, NoteSymbol, SleepSymbol } from "./NidoSymbols";

type JournalEvent = { time: string; title: string; note: string; kind: "feed" | "diaper" | "care" | "note" };

function JournalEventIcon({ kind }: { kind: JournalEvent["kind"] }) {
  const Icon = kind === "feed" ? FeedSymbol : kind === "diaper" ? DiaperSymbol : kind === "care" ? CareSymbol : NoteSymbol;
  return <i className={`journal-event-icon ${kind}`}><Icon /></i>;
}

export default function FamilyJournal() {
  const [sleeping, setSleeping] = useState(false);
  const [events, setEvents] = useState<JournalEvent[]>([]);
  const add = (kind: JournalEvent["kind"], title: string, note: string) => setEvents((current) => [{ kind, time: "Ahora", title, note }, ...current]);

  return <section className="journal-shell">
    <header className="journal-header"><div className="journal-mark"><NidoMark /></div><span>Nido</span><button aria-label="Perfil de Marco">M</button></header>
    <main className="journal-page">
      <p className="journal-date">Jueves · 27 de agosto</p>
      <h1>Hoy con Marco</h1>
      <p className="journal-lede">Un día nuevo, todavía por escribir.</p>
      <button className={`journal-sleep ${sleeping ? "active" : ""}`} onClick={() => setSleeping(!sleeping)}>
        <i className="journal-sleep-symbol"><SleepSymbol /></i>
        <span><small>{sleeping ? "Marco está durmiendo" : "Primer descanso"}</small><strong>{sleeping ? "00:12" : "Empezar sueño"}</strong></span>
        <em>{sleeping ? "Terminar" : "Iniciar"}</em>
      </button>
      <div className="journal-rule"><span>La historia de hoy</span></div>
      <section className="journal-timeline">
        {events.length ? events.map((event, index) => <article key={`${event.title}-${index}`}><time>{event.time}</time><JournalEventIcon kind={event.kind} /><div><strong>{event.title}</strong><p>{event.note}</p></div></article>) : <div className="journal-opening"><MomentSymbol /><p>El primer registro aparecerá aquí como un momento del día, no como una cifra en un dashboard.</p></div>}
      </section>
    </main>
    <nav className="journal-compose" aria-label="Añadir al día">
      <button onClick={() => add("feed", "Toma", "Biberón · cantidad por indicar")}><i><FeedSymbol /></i><span>Toma</span></button>
      <button onClick={() => add("diaper", "Pañal", "Cambio registrado")}><i><DiaperSymbol /></i><span>Pañal</span></button>
      <button onClick={() => add("care", "Cuidado", "Nuevo momento de cuidado")}><i><CareSymbol /></i><span>Cuidado</span></button>
      <button onClick={() => add("note", "Nota", "Un detalle para recordar")}><i><NoteSymbol /></i><span>Nota</span></button>
    </nav>
  </section>;
}
