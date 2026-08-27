"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import {
  Activity, Baby, BarChart3, Bath, Bell, Check, ChevronLeft, ChevronRight,
  Clock3, Droplets, HeartPulse, Home, Milk, Moon, MoreHorizontal, NotebookPen,
  Plus, Settings, Sparkles, Stethoscope, Sun, Thermometer, X,
} from "lucide-react";

type View = "hoy" | "historial" | "tendencias" | "ajustes";
type EntryKind = "sleep" | "feed" | "diaper" | "health";
type Entry = { id: string; kind: EntryKind; title: string; detail: string; time: string; duration?: number };

const labels: Record<EntryKind, { label: string; icon: typeof Moon; className: string }> = {
  sleep: { label: "Sueño", icon: Moon, className: "sleep" },
  feed: { label: "Toma", icon: Milk, className: "feed" },
  diaper: { label: "Pañal", icon: Droplets, className: "diaper" },
  health: { label: "Cuidado", icon: HeartPulse, className: "health" },
};

const sampleEntries: Entry[] = [
  { id: "sample-1", kind: "feed", title: "Biberón", detail: "120 ml · Leche materna", time: "09:12" },
  { id: "sample-2", kind: "sleep", title: "Siesta de la mañana", detail: "1 h 18 min · Cuna", time: "07:46", duration: 78 },
  { id: "sample-3", kind: "diaper", title: "Pañal", detail: "Mojado", time: "07:21" },
  { id: "sample-4", kind: "feed", title: "Pecho", detail: "18 min · Izquierdo", time: "06:48" },
  { id: "sample-5", kind: "sleep", title: "Sueño nocturno", detail: "7 h 42 min · 2 despertares", time: "22:54", duration: 462 },
];

const weekSleep = [12.7, 13.4, 12.9, 14.1, 13.8, 13.2, 13.9];
const weekLabels = ["V", "S", "D", "L", "M", "X", "J"];

function currentTime() {
  return new Intl.DateTimeFormat("es-ES", { hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date());
}

function durationLabel(seconds: number) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours) return `${hours} h ${minutes} min`;
  return `${minutes || 1} min`;
}

function IconBubble({ kind }: { kind: EntryKind }) {
  const config = labels[kind];
  const Icon = config.icon;
  return <span className={`event-icon ${config.className}`}><Icon size={19} strokeWidth={2} /></span>;
}

export default function NidoApp() {
  const [view, setView] = useState<View>("hoy");
  const [entries, setEntries] = useState<Entry[]>(sampleEntries);
  const [modal, setModal] = useState<EntryKind | null>(null);
  const [activeSleep, setActiveSleep] = useState<number | null>(null);
  const [, setTick] = useState(0);
  const [toast, setToast] = useState("");
  const [filter, setFilter] = useState<"all" | EntryKind>("all");

  useEffect(() => {
    const saved = localStorage.getItem("nido-entries");
    const sleep = localStorage.getItem("nido-active-sleep");
    if (saved) setEntries(JSON.parse(saved));
    if (sleep) setActiveSleep(Number(sleep));
  }, []);

  useEffect(() => { localStorage.setItem("nido-entries", JSON.stringify(entries)); }, [entries]);

  useEffect(() => {
    if (!activeSleep) return;
    const timer = window.setInterval(() => setTick((value) => value + 1), 1000);
    return () => window.clearInterval(timer);
  }, [activeSleep]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(""), 2800);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const sleepSeconds = activeSleep ? Math.max(0, Math.floor((Date.now() - activeSleep) / 1000)) : 0;
  const filteredEntries = useMemo(() => filter === "all" ? entries : entries.filter((entry) => entry.kind === filter), [entries, filter]);

  function addEntry(entry: Omit<Entry, "id" | "time">) {
    setEntries((current) => [{ ...entry, id: crypto.randomUUID(), time: currentTime() }, ...current]);
    setModal(null);
    setToast(`${entry.title} guardado`);
  }

  function toggleSleep() {
    if (!activeSleep) {
      const started = Date.now();
      setActiveSleep(started);
      localStorage.setItem("nido-active-sleep", String(started));
      setToast("Sueño iniciado");
      return;
    }
    const duration = Math.max(1, Math.round((Date.now() - activeSleep) / 60000));
    setEntries((current) => [{ id: crypto.randomUUID(), kind: "sleep", title: "Sueño", detail: `${duration} min · Temporizador`, time: currentTime(), duration }, ...current]);
    setActiveSleep(null);
    localStorage.removeItem("nido-active-sleep");
    setToast("Sueño guardado");
  }

  return (
    <div className="app-frame">
      <aside className="sidebar" aria-label="Navegación principal">
        <div className="brand"><span><Baby size={22} /></span><strong>Nido</strong></div>
        <nav>
          <NavButton active={view === "hoy"} onClick={() => setView("hoy")} icon={Home} label="Hoy" />
          <NavButton active={view === "historial"} onClick={() => setView("historial")} icon={NotebookPen} label="Historial" />
          <NavButton active={view === "tendencias"} onClick={() => setView("tendencias")} icon={BarChart3} label="Tendencias" />
          <NavButton active={view === "ajustes"} onClick={() => setView("ajustes")} icon={Settings} label="Ajustes" />
        </nav>
        <div className="baby-mini"><div className="baby-avatar">L</div><div><strong>Leo</strong><small>4 meses y 12 días</small></div><MoreHorizontal size={18} /></div>
      </aside>

      <main className="app-shell">
        {view === "hoy" && <TodayView activeSleep={activeSleep} sleepSeconds={sleepSeconds} onSleep={toggleSleep} onOpen={setModal} entries={entries} onViewHistory={() => setView("historial")} />}
        {view === "historial" && <HistoryView entries={filteredEntries} filter={filter} setFilter={setFilter} />}
        {view === "tendencias" && <TrendsView />}
        {view === "ajustes" && <SettingsView />}
      </main>

      <nav className="bottom-nav" aria-label="Navegación principal">
        <NavButton active={view === "hoy"} onClick={() => setView("hoy")} icon={Home} label="Hoy" />
        <NavButton active={view === "historial"} onClick={() => setView("historial")} icon={NotebookPen} label="Historial" />
        <NavButton active={view === "tendencias"} onClick={() => setView("tendencias")} icon={BarChart3} label="Tendencias" />
        <NavButton active={view === "ajustes"} onClick={() => setView("ajustes")} icon={Settings} label="Ajustes" />
      </nav>

      {modal && <LogSheet kind={modal} onClose={() => setModal(null)} onAdd={addEntry} onSleep={toggleSleep} activeSleep={activeSleep} />}
      {toast && <div className="toast" role="status"><Check size={17} />{toast}</div>}
    </div>
  );
}

function NavButton({ active, onClick, icon: Icon, label }: { active: boolean; onClick: () => void; icon: typeof Home; label: string }) {
  return <button className={`nav-button ${active ? "active" : ""}`} onClick={onClick}><Icon size={20} strokeWidth={active ? 2.4 : 1.8} /><span>{label}</span></button>;
}

function TodayView({ activeSleep, sleepSeconds, onSleep, onOpen, entries, onViewHistory }: { activeSleep: number | null; sleepSeconds: number; onSleep: () => void; onOpen: (kind: EntryKind) => void; entries: Entry[]; onViewHistory: () => void }) {
  return <>
    <header className="topbar"><div><p className="eyebrow">Jueves, 27 de agosto</p><h1>Buenos días, Marcos</h1></div><button className="header-action" aria-label="Notificaciones"><Bell size={20} /><span /></button></header>
    <section className={`sleep-card ${activeSleep ? "is-active" : ""}`} aria-labelledby="next-sleep">
      <div className="sleep-orb" aria-hidden="true">{activeSleep ? <Clock3 /> : <Moon />}</div>
      <div className="sleep-copy"><p className="card-kicker">{activeSleep ? "Leo está durmiendo" : "Próximo descanso"}</p><h2 id="next-sleep">{activeSleep ? durationLabel(sleepSeconds) : "Siesta en 42 min"}</h2><p>{activeSleep ? "El temporizador sigue activo" : "Ventana ideal entre 10:45 y 11:05"}</p></div>
      <button className="primary-button" onClick={onSleep}>{activeSleep ? "Terminar sueño" : "Empezar sueño"}</button>
      {!activeSleep && <div className="confidence"><Sparkles size={13} /><span>Basado en los últimos 7 días</span></div>}
    </section>
    <section className="quick-section" aria-labelledby="quick-title">
      <div className="section-heading"><div><p className="eyebrow">Leo · 4 meses</p><h2 id="quick-title">¿Qué acaba de pasar?</h2></div><button className="text-button" onClick={onViewHistory}>Ver todo</button></div>
      <div className="quick-grid"><QuickAction className="sleep" icon={Moon} title="Sueño" detail={activeSleep ? "En curso" : "Hace 1 h 18 min"} onClick={() => onOpen("sleep")} /><QuickAction className="feed" icon={Milk} title="Toma" detail="120 ml · 9:12" onClick={() => onOpen("feed")} /><QuickAction className="diaper" icon={Droplets} title="Pañal" detail="Hace 2 h" onClick={() => onOpen("diaper")} /><QuickAction className="more" icon={Plus} title="Más" detail="Salud, baño y más" onClick={() => onOpen("health")} /></div>
    </section>
    <div className="dashboard-grid"><section className="panel timeline-panel"><div className="panel-heading"><div><p className="eyebrow">Hoy</p><h2>El día de Leo</h2></div><button className="circle-button" aria-label="Añadir registro" onClick={() => onOpen("health")}><Plus size={19} /></button></div><div className="timeline">{entries.slice(0, 4).map((entry) => <TimelineRow key={entry.id} entry={entry} />)}</div></section><section className="panel summary-panel"><div className="panel-heading"><div><p className="eyebrow">Resumen diario</p><h2>Todo va bien</h2></div><span className="status-dot"><Check size={16} /></span></div><div className="summary-list"><Summary icon={Moon} label="Sueño" value="9 h 12 min" note="de 13–15 h" /><Summary icon={Milk} label="Tomas" value="4" note="480 ml" /><Summary icon={Droplets} label="Pañales" value="3" note="ritmo habitual" /></div><p className="gentle-note"><Sparkles size={15} /> Leo lleva una mañana muy parecida a su media.</p></section></div>
  </>;
}

function QuickAction({ className, icon: Icon, title, detail, onClick }: { className: string; icon: typeof Moon; title: string; detail: string; onClick: () => void }) { return <button className={`quick-action ${className}`} onClick={onClick}><span><Icon size={21} /></span><strong>{title}</strong><small>{detail}</small></button>; }
function TimelineRow({ entry }: { entry: Entry }) { return <div className="timeline-row"><div className="timeline-time">{entry.time}</div><IconBubble kind={entry.kind} /><div className="timeline-copy"><strong>{entry.title}</strong><small>{entry.detail}</small></div><ChevronRight size={17} className="row-chevron" /></div>; }
function Summary({ icon: Icon, label, value, note }: { icon: typeof Moon; label: string; value: string; note: string }) { return <div className="summary-row"><span><Icon size={18} /></span><strong>{label}</strong><div><b>{value}</b><small>{note}</small></div></div>; }

function HistoryView({ entries, filter, setFilter }: { entries: Entry[]; filter: "all" | EntryKind; setFilter: (value: "all" | EntryKind) => void }) {
  return <section className="page-view"><header className="page-header"><div><p className="eyebrow">Registro completo</p><h1>Historial</h1></div><div className="date-stepper"><button aria-label="Día anterior"><ChevronLeft size={18} /></button><strong>Hoy</strong><button aria-label="Día siguiente" disabled><ChevronRight size={18} /></button></div></header><div className="filter-pills">{(["all", "sleep", "feed", "diaper", "health"] as const).map((item) => <button key={item} className={filter === item ? "active" : ""} onClick={() => setFilter(item)}>{item === "all" ? "Todo" : labels[item].label}</button>)}</div><div className="history-layout"><div className="panel history-list"><div className="day-divider"><span>Hoy</span><small>{entries.length} registros</small></div>{entries.map((entry) => <TimelineRow key={entry.id} entry={entry} />)}</div><aside className="panel share-card"><span className="share-icon"><Stethoscope size={23} /></span><h2>Listo para la consulta</h2><p>Un resumen claro de los últimos 7 días para compartir con el pediatra.</p><button>Preparar resumen</button></aside></div></section>;
}

function TrendsView() {
  return <section className="page-view"><header className="page-header"><div><p className="eyebrow">Últimos 7 días</p><h1>Tendencias</h1></div><button className="period-button">Semana <ChevronRight size={16} /></button></header><div className="insight-hero"><div><span className="insight-badge"><Sparkles size={14} /> Ritmo estable</span><h2>Leo duerme mejor los días con una última siesta corta.</h2><p>Es una observación de sus datos, no una recomendación médica.</p></div><div className="big-stat"><strong>+34</strong><span>min de sueño</span></div></div><div className="trends-grid"><section className="panel chart-card"><div className="panel-heading"><div><p className="eyebrow">Sueño total</p><h2>13 h 26 min</h2></div><span className="trend-positive">+4%</span></div><div className="bar-chart" aria-label="Sueño total de los últimos siete días">{weekSleep.map((value, index) => <div className="bar-column" key={weekLabels[index]}><div className="bar-track"><span style={{ height: `${(value / 15) * 100}%` }} className={index === 6 ? "today" : ""} /></div><small>{weekLabels[index]}</small></div>)}</div></section><section className="panel rhythm-card"><div className="panel-heading"><div><p className="eyebrow">Ritmo habitual</p><h2>Un día de Leo</h2></div><Sun size={21} /></div><div className="rhythm-line"><span className="night first" /><span className="awake" /><span className="nap one" /><span className="awake second" /><span className="nap two" /><span className="awake third" /><span className="night last" /></div><div className="rhythm-labels"><span>00</span><span>06</span><span>12</span><span>18</span><span>24</span></div><div className="rhythm-key"><span><i className="key-night" />Sueño</span><span><i className="key-awake" />Despierto</span></div></section></div><section className="panel pattern-list"><div className="panel-heading"><div><p className="eyebrow">Patrones suaves</p><h2>Lo que hemos observado</h2></div></div><div className="pattern-grid"><div><Clock3 /><strong>Ventana de sueño</strong><p>Suele mostrar cansancio tras 1 h 45 min despierto.</p></div><div><Milk /><strong>Tomas</strong><p>La cantidad media ha subido 8% esta semana.</p></div><div><Moon /><strong>Noche</strong><p>Se duerme unos 18 min antes que la semana pasada.</p></div></div></section></section>;
}

function SettingsView() {
  return <section className="page-view settings-view"><header className="page-header"><div><p className="eyebrow">Tu familia</p><h1>Ajustes</h1></div></header><section className="profile-card panel"><div className="large-avatar">L</div><div><h2>Leo</h2><p>14 de abril de 2026 · 4 meses</p></div><button>Editar</button></section><section className="settings-group panel"><h2>Cuidado diario</h2><SettingRow icon={Bell} title="Avisos tranquilos" detail="Solo cuando realmente ayudan" /><SettingRow icon={Activity} title="Actividades visibles" detail="Sueño, tomas, pañales y salud" /><SettingRow icon={Baby} title="Cuidadores" detail="Marcos · Uso personal" /></section><section className="settings-group panel"><h2>Salud y privacidad</h2><SettingRow icon={Stethoscope} title="Datos del pediatra" detail="Sin configurar" /><SettingRow icon={HeartPulse} title="Salud y crecimiento" detail="Percentiles, vacunas y medicación" /><SettingRow icon={Settings} title="Tus datos" detail="Guardados solo en este dispositivo" /></section></section>;
}

function SettingRow({ icon: Icon, title, detail }: { icon: typeof Bell; title: string; detail: string }) { return <button className="setting-row"><span><Icon size={19} /></span><div><strong>{title}</strong><small>{detail}</small></div><ChevronRight size={17} /></button>; }

function LogSheet({ kind, onClose, onAdd, onSleep, activeSleep }: { kind: EntryKind; onClose: () => void; onAdd: (entry: Omit<Entry, "id" | "time">) => void; onSleep: () => void; activeSleep: number | null }) {
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    if (kind === "feed") onAdd({ kind, title: String(data.get("feedType")), detail: `${data.get("amount") || 120} ml · ${data.get("milkType")}` });
    if (kind === "diaper") onAdd({ kind, title: "Pañal", detail: String(data.get("diaperType")) });
    if (kind === "health") onAdd({ kind, title: String(data.get("careType")), detail: String(data.get("note") || "Sin notas") });
  }
  const config = labels[kind]; const Icon = config.icon;
  return <div className="sheet-backdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}><section className="log-sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title"><div className="sheet-handle" /><header><span className={`event-icon ${config.className}`}><Icon size={20} /></span><div><p className="eyebrow">Registrar ahora</p><h2 id="sheet-title">{config.label}</h2></div><button className="circle-button" onClick={onClose} aria-label="Cerrar"><X size={19} /></button></header>{kind === "sleep" ? <div className="sleep-sheet"><div className="sleep-sheet-orb"><Moon size={30} /></div><h3>{activeSleep ? "Leo está durmiendo" : "¿Empezamos a contar?"}</h3><p>{activeSleep ? "Al terminar guardaremos la duración automáticamente." : "Puedes cerrar la app. El temporizador seguirá guardado en este dispositivo."}</p><button className="sheet-submit" onClick={() => { onSleep(); onClose(); }}>{activeSleep ? "Terminar y guardar" : "Empezar sueño"}</button><button className="secondary-sheet-button" onClick={() => onAdd({ kind: "sleep", title: "Siesta", detail: "45 min · Añadido manualmente", duration: 45 })}>Añadir sueño anterior</button></div> : <form onSubmit={submit}>{kind === "feed" && <><label>Tipo<select name="feedType"><option>Biberón</option><option>Pecho</option><option>Sólidos</option></select></label><div className="form-row"><label>Cantidad<div className="input-suffix"><input name="amount" type="number" inputMode="numeric" defaultValue="120" /><span>ml</span></div></label><label>Contenido<select name="milkType"><option>Leche materna</option><option>Fórmula</option><option>Mixto</option></select></label></div></>}{kind === "diaper" && <fieldset><legend>¿Cómo estaba?</legend><div className="choice-grid">{["Mojado", "Sucio", "Ambos", "Seco"].map((value) => <label key={value}><input type="radio" name="diaperType" value={value} defaultChecked={value === "Mojado"} /><span>{value}</span></label>)}</div></fieldset>}{kind === "health" && <><label>Actividad<select name="careType"><option>Baño</option><option>Temperatura</option><option>Medicación</option><option>Crecimiento</option><option>Hito</option></select></label><label>Nota<input name="note" placeholder="Añade un detalle, si quieres" /></label><div className="care-shortcuts"><Bath /><Thermometer /><Stethoscope /></div></>}<button className="sheet-submit" type="submit">Guardar</button></form>}</section></div>;
}
