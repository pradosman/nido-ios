"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import {
  Activity, Baby, BarChart3, Bath, Bell, Check, ChevronRight, Clock3,
  Droplets, HeartPulse, Home, Milk, Moon, MoreHorizontal, NotebookPen,
  Plus, Settings, Sparkles, Stethoscope, Thermometer, X,
} from "lucide-react";
import {
  ageInMonths, calculateDayMetrics, calculateWeekSleep, entriesForDay,
  formatMinutes, wakeWindowMinutes,
} from "./nido-data";
import type { Entry, EntryKind, Profile } from "./nido-data";

type View = "hoy" | "historial" | "tendencias" | "ajustes";

const labels: Record<EntryKind, { label: string; icon: typeof Moon; className: string }> = {
  sleep: { label: "Sueño", icon: Moon, className: "sleep" },
  feed: { label: "Toma", icon: Milk, className: "feed" },
  diaper: { label: "Pañal", icon: Droplets, className: "diaper" },
  health: { label: "Cuidado", icon: HeartPulse, className: "health" },
};

function durationLabel(seconds: number) {
  return formatMinutes(Math.max(1, Math.floor(seconds / 60)));
}

function formatClock(timestamp: number) {
  return new Intl.DateTimeFormat("es-ES", { hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(timestamp));
}

function formatDate(timestamp: number) {
  const value = new Intl.DateTimeFormat("es-ES", { weekday: "long", day: "numeric", month: "long" }).format(new Date(timestamp));
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function formatBirthDate(value: string) {
  return new Intl.DateTimeFormat("es-ES", { day: "numeric", month: "long", year: "numeric" }).format(new Date(`${value}T12:00:00`));
}

function relativeTime(timestamp: number, now: number) {
  const minutes = Math.max(0, Math.floor((now - timestamp) / 60_000));
  if (minutes < 1) return "Ahora mismo";
  if (minutes < 60) return `Hace ${minutes} min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `Hace ${hours} h`;
  return new Intl.DateTimeFormat("es-ES", { day: "numeric", month: "short" }).format(new Date(timestamp));
}

function ageLabel(profile: Profile) {
  const months = ageInMonths(profile.birthDate);
  if (months < 1) return "Recién nacido";
  return `${months} ${months === 1 ? "mes" : "meses"}`;
}

function initials(name: string) {
  return name.trim().charAt(0).toUpperCase();
}

function IconBubble({ kind }: { kind: EntryKind }) {
  const config = labels[kind];
  const Icon = config.icon;
  return <span className={`event-icon ${config.className}`}><Icon size={19} strokeWidth={2} /></span>;
}

export default function NidoApp() {
  const [view, setView] = useState<View>("hoy");
  const [profile, setProfile] = useState<Profile | null | undefined>(undefined);
  const [entries, setEntries] = useState<Entry[]>([]);
  const [modal, setModal] = useState<EntryKind | null>(null);
  const [editingProfile, setEditingProfile] = useState(false);
  const [activeSleep, setActiveSleep] = useState<number | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const [toast, setToast] = useState("");
  const [filter, setFilter] = useState<"all" | EntryKind>("all");
  const [loadError, setLoadError] = useState("");

  useEffect(() => {
    const sleep = localStorage.getItem("nido-active-sleep");
    const restoreSleep = window.setTimeout(() => {
      if (sleep) setActiveSleep(Number(sleep));
    }, 0);
    localStorage.removeItem("nido-entries");
    void (async () => {
      try {
        const response = await fetch("/api/nido", { cache: "no-store" });
        if (!response.ok) throw new Error("No hemos podido abrir vuestro espacio.");
        const data = await response.json() as { profile: Profile | null; entries: Entry[] };
        setProfile(data.profile);
        setEntries(data.entries ?? []);
      } catch (cause) {
        setProfile(null);
        setLoadError(cause instanceof Error ? cause.message : "No hemos podido abrir vuestro espacio.");
      }
    })();
    return () => window.clearTimeout(restoreSleep);
  }, []);

  useEffect(() => {
    if (!activeSleep) return;
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [activeSleep]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(""), 2800);
    return () => window.clearTimeout(timer);
  }, [toast]);

  async function saveProfile(nextProfile: Profile) {
    const response = await fetch("/api/nido/profile", {
      method: "PUT",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(nextProfile),
    });
    if (!response.ok) throw new Error("No hemos podido guardar los datos.");
    const result = await response.json() as { profile: Profile };
    setProfile(result.profile);
    setEditingProfile(false);
    setLoadError("");
    return result.profile;
  }

  async function addEntry(entry: Omit<Entry, "id" | "occurredAt">) {
    const nextEntry: Entry = { ...entry, id: crypto.randomUUID(), occurredAt: Date.now() };
    try {
      const response = await fetch("/api/nido/entries", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(nextEntry),
      });
      if (!response.ok) throw new Error("No se ha podido guardar.");
      const result = await response.json() as { entry: Entry };
      setEntries((current) => [result.entry, ...current]);
      setModal(null);
      setToast(`${entry.title} guardado`);
    } catch (cause) {
      setToast(cause instanceof Error ? cause.message : "No se ha podido guardar.");
    }
  }

  async function toggleSleep() {
    if (!activeSleep) {
      const started = Date.now();
      setActiveSleep(started);
      localStorage.setItem("nido-active-sleep", String(started));
      setToast("Sueño iniciado");
      return;
    }
    const durationMinutes = Math.max(1, Math.round((Date.now() - activeSleep) / 60_000));
    await addEntry({ kind: "sleep", title: "Sueño", detail: `${formatMinutes(durationMinutes)} · Temporizador`, durationMinutes, amountMl: null });
    setActiveSleep(null);
    localStorage.removeItem("nido-active-sleep");
  }

  const filteredEntries = useMemo(() => filter === "all" ? entries : entries.filter((entry) => entry.kind === filter), [entries, filter]);
  const sleepSeconds = activeSleep ? Math.max(0, Math.floor((now - activeSleep) / 1000)) : 0;

  if (profile === undefined) return <LoadingState />;
  if (!profile) return <Onboarding onSave={saveProfile} loadError={loadError} />;

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
        <div className="baby-mini"><div className="baby-avatar">{initials(profile.babyName)}</div><div><strong>{profile.babyName}</strong><small>{ageLabel(profile)}</small></div><MoreHorizontal size={18} /></div>
      </aside>

      <header className="mobile-chrome">
        <div className="mobile-brand"><span><Baby size={18} /></span><strong>Nido</strong></div>
        <button type="button" className="mobile-profile" onClick={() => setView("ajustes")} aria-label={`Abrir ajustes de ${profile.babyName}`}>{initials(profile.babyName)}</button>
      </header>

      <main className="app-shell">
        {view === "hoy" && <TodayView profile={profile} entries={entries} now={now} activeSleep={activeSleep} sleepSeconds={sleepSeconds} onSleep={toggleSleep} onOpen={setModal} onViewHistory={() => setView("historial")} />}
        {view === "historial" && <HistoryView entries={filteredEntries} filter={filter} setFilter={setFilter} />}
        {view === "tendencias" && <TrendsView profile={profile} entries={entries} now={now} />}
        {view === "ajustes" && <SettingsView profile={profile} onEdit={() => setEditingProfile(true)} />}
      </main>

      <nav className="bottom-nav" aria-label="Navegación principal">
        <NavButton active={view === "hoy"} onClick={() => setView("hoy")} icon={Home} label="Hoy" />
        <NavButton active={view === "historial"} onClick={() => setView("historial")} icon={NotebookPen} label="Historial" />
        <NavButton active={view === "tendencias"} onClick={() => setView("tendencias")} icon={BarChart3} label="Tendencias" />
        <NavButton active={view === "ajustes"} onClick={() => setView("ajustes")} icon={Settings} label="Ajustes" />
      </nav>

      {modal && <LogSheet kind={modal} onClose={() => setModal(null)} onAdd={addEntry} onSleep={toggleSleep} activeSleep={activeSleep} />}
      {editingProfile && <ProfileSheet profile={profile} onClose={() => setEditingProfile(false)} onSave={saveProfile} />}
      {toast && <div className="toast" role="status"><Check size={17} />{toast}</div>}
    </div>
  );
}

function LoadingState() {
  return <div className="app-loading"><div className="brand"><span><Baby size={22} /></span><strong>Nido</strong></div><p>Preparando vuestro espacio…</p></div>;
}

function Onboarding({ onSave, loadError }: { onSave: (profile: Profile) => Promise<Profile>; loadError: string }) {
  return <main className="onboarding-shell"><section className="onboarding-card"><div className="onboarding-brand"><span><Baby size={23} /></span>Nido</div><div className="onboarding-step">Primeros pasos · 1 de 1</div><h1>Un espacio para vuestro día a día.</h1><p className="onboarding-intro">Empezaremos desde cero. Solo necesitamos saber cómo llamaros para adaptar cada registro.</p><ProfileForm onSave={onSave} submitLabel="Crear nuestro espacio" initialError={loadError} /><p className="privacy-note">Privado y sin datos de muestra. Empezaréis con el historial completamente vacío.</p></section><aside className="onboarding-visual" aria-hidden="true"><div className="welcome-orb"><Moon /></div><div className="welcome-copy"><span>Menos memoria.</span><strong>Más presencia.</strong></div><div className="floating-card first"><Milk /><div><b>Toma</b><small>Registra en segundos</small></div></div><div className="floating-card second"><Sparkles /><div><b>Patrones reales</b><small>Solo con vuestros datos</small></div></div></aside></main>;
}

function ProfileForm({ onSave, profile, submitLabel, initialError = "" }: { onSave: (profile: Profile) => Promise<Profile>; profile?: Profile; submitLabel: string; initialError?: string }) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(initialError);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSaving(true);
    setError("");
    const data = new FormData(event.currentTarget);
    try {
      await onSave({ caregiverName: String(data.get("caregiverName")), babyName: String(data.get("babyName")), birthDate: String(data.get("birthDate")) });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "No hemos podido guardar los datos.");
      setSaving(false);
    }
  }
  return <form className="profile-form" onSubmit={submit}><label>¿Cómo te llamas?<input name="caregiverName" autoComplete="name" placeholder="Tu nombre" defaultValue={profile?.caregiverName} required /></label><label>¿Cómo se llama el bebé?<input name="babyName" placeholder="Nombre del bebé" defaultValue={profile?.babyName} required /></label><label>Fecha de nacimiento<input name="birthDate" type="date" max={new Date().toISOString().slice(0, 10)} defaultValue={profile?.birthDate} required /></label>{error && <p className="form-error">{error}</p>}<button className="onboarding-submit" disabled={saving}>{saving ? "Guardando…" : submitLabel}<ChevronRight size={18} /></button></form>;
}

function NavButton({ active, onClick, icon: Icon, label }: { active: boolean; onClick: () => void; icon: typeof Home; label: string }) {
  return <button type="button" className={`nav-button ${active ? "active" : ""}`} aria-current={active ? "page" : undefined} onClick={onClick}><Icon size={20} strokeWidth={active ? 2.4 : 1.8} /><span>{label}</span></button>;
}

function TodayView({ profile, entries, now, activeSleep, sleepSeconds, onSleep, onOpen, onViewHistory }: { profile: Profile; entries: Entry[]; now: number; activeSleep: number | null; sleepSeconds: number; onSleep: () => void; onOpen: (kind: EntryKind) => void; onViewHistory: () => void }) {
  const todayEntries = entriesForDay(entries, now);
  const metrics = calculateDayMetrics(entries);
  const lastSleep = entries.find((entry) => entry.kind === "sleep");
  const lastFeed = entries.find((entry) => entry.kind === "feed");
  const lastDiaper = entries.find((entry) => entry.kind === "diaper");
  const age = ageInMonths(profile.birthDate);
  const nextSleep = lastSleep ? lastSleep.occurredAt + wakeWindowMinutes(age) * 60_000 : null;
  const sleepDiff = nextSleep ? Math.ceil((nextSleep - now) / 60_000) : null;
  const sleepTitle = activeSleep ? durationLabel(sleepSeconds) : !lastSleep ? "Registra el primer sueño" : sleepDiff && sleepDiff > 0 ? `Siesta en ${sleepDiff} min` : "Puede necesitar descansar";
  const sleepDetail = activeSleep ? "El temporizador sigue activo" : nextSleep ? `Ventana orientativa: ${formatClock(nextSleep - 10 * 60_000)}–${formatClock(nextSleep + 10 * 60_000)}` : "Aprenderemos su ritmo con cada registro";

  return <>
    <header className="topbar"><div><p className="eyebrow">{formatDate(now)}</p><h1><span className="desktop-greeting">Buenos días, {profile.caregiverName}</span><span className="mobile-greeting">Hola, {profile.caregiverName}</span></h1></div><button className="header-action" aria-label="Notificaciones"><Bell size={20} /></button></header>
    <section className={`sleep-card ${activeSleep ? "is-active" : ""}`} aria-labelledby="next-sleep"><div className="sleep-orb" aria-hidden="true">{activeSleep ? <Clock3 /> : <Moon />}</div><div className="sleep-copy"><p className="card-kicker">{activeSleep ? `${profile.babyName} está durmiendo` : lastSleep ? "Próximo descanso" : "Empezamos a conoceros"}</p><h2 id="next-sleep">{sleepTitle}</h2><p>{sleepDetail}</p></div><button className="primary-button" onClick={onSleep}>{activeSleep ? "Terminar sueño" : "Empezar sueño"}</button>{lastSleep && !activeSleep && <div className="confidence"><Sparkles size={13} /><span>Estimación orientativa según edad y último sueño</span></div>}</section>
    <section className="quick-section" aria-labelledby="quick-title"><div className="section-heading"><div><p className="eyebrow">{profile.babyName} · {ageLabel(profile)}</p><h2 id="quick-title">¿Qué acaba de pasar?</h2></div><button className="text-button" onClick={onViewHistory}>Ver todo</button></div><div className="quick-grid"><QuickAction className="sleep" icon={Moon} title="Sueño" detail={activeSleep ? "En curso" : lastSleep ? relativeTime(lastSleep.occurredAt, now) : "Sin registros"} onClick={() => onOpen("sleep")} /><QuickAction className="feed" icon={Milk} title="Toma" detail={lastFeed ? `${lastFeed.amountMl ? `${lastFeed.amountMl} ml · ` : ""}${relativeTime(lastFeed.occurredAt, now)}` : "Sin registros"} onClick={() => onOpen("feed")} /><QuickAction className="diaper" icon={Droplets} title="Pañal" detail={lastDiaper ? relativeTime(lastDiaper.occurredAt, now) : "Sin registros"} onClick={() => onOpen("diaper")} /><QuickAction className="more" icon={Plus} title="Más" detail="Salud, baño y más" onClick={() => onOpen("health")} /></div></section>
    <div className="dashboard-grid"><section className="panel timeline-panel"><div className="panel-heading"><div><p className="eyebrow">Hoy</p><h2>El día de {profile.babyName}</h2></div><button className="circle-button" aria-label="Añadir registro" onClick={() => onOpen("health")}><Plus size={19} /></button></div>{todayEntries.length ? <div className="timeline">{todayEntries.slice(0, 5).map((entry) => <TimelineRow key={entry.id} entry={entry} />)}</div> : <EmptyState icon={NotebookPen} title="Hoy empieza aquí" body="El primer registro aparecerá en este espacio." />}</section><section className="panel summary-panel"><div className="panel-heading"><div><p className="eyebrow">Resumen diario</p><h2>{todayEntries.length ? "Hoy, de un vistazo" : "Aún sin datos"}</h2></div>{todayEntries.length ? <span className="status-dot"><Check size={16} /></span> : null}</div><div className="summary-list"><Summary icon={Moon} label="Sueño" value={formatMinutes(metrics.sleepMinutes)} note={`${todayEntries.filter((entry) => entry.kind === "sleep").length} registros`} /><Summary icon={Milk} label="Tomas" value={String(metrics.feeds)} note={metrics.feedMl ? `${metrics.feedMl} ml` : "sin cantidad"} /><Summary icon={Droplets} label="Pañales" value={String(metrics.diapers)} note="registrados hoy" /></div><p className="gentle-note"><Sparkles size={15} /> {todayEntries.length ? "Este resumen usa únicamente los registros de hoy." : "Registra una actividad para crear vuestro primer resumen."}</p></section></div>
  </>;
}

function QuickAction({ className, icon: Icon, title, detail, onClick }: { className: string; icon: typeof Moon; title: string; detail: string; onClick: () => void }) { return <button className={`quick-action ${className}`} onClick={onClick}><span><Icon size={21} /></span><strong>{title}</strong><small>{detail}</small></button>; }
function TimelineRow({ entry }: { entry: Entry }) { return <div className="timeline-row"><div className="timeline-time">{formatClock(entry.occurredAt)}</div><IconBubble kind={entry.kind} /><div className="timeline-copy"><strong>{entry.title}</strong><small>{entry.detail}</small></div><ChevronRight size={17} className="row-chevron" /></div>; }
function Summary({ icon: Icon, label, value, note }: { icon: typeof Moon; label: string; value: string; note: string }) { return <div className="summary-row"><span><Icon size={18} /></span><strong>{label}</strong><div><b>{value}</b><small>{note}</small></div></div>; }
function EmptyState({ icon: Icon, title, body }: { icon: typeof NotebookPen; title: string; body: string }) { return <div className="empty-state"><span><Icon size={22} /></span><strong>{title}</strong><p>{body}</p></div>; }

function HistoryView({ entries, filter, setFilter }: { entries: Entry[]; filter: "all" | EntryKind; setFilter: (value: "all" | EntryKind) => void }) {
  return <section className="page-view"><header className="page-header"><div><p className="eyebrow">Registro completo</p><h1>Historial</h1></div></header><div className="filter-pills">{(["all", "sleep", "feed", "diaper", "health"] as const).map((item) => <button key={item} className={filter === item ? "active" : ""} onClick={() => setFilter(item)}>{item === "all" ? "Todo" : labels[item].label}</button>)}</div><div className="history-layout"><div className="panel history-list"><div className="day-divider"><span>Todos los registros</span><small>{entries.length}</small></div>{entries.length ? entries.map((entry) => <TimelineRow key={entry.id} entry={entry} />) : <EmptyState icon={NotebookPen} title="El historial está vacío" body="Los registros que guardes aparecerán aquí, ordenados del más reciente al más antiguo." />}</div><aside className="panel share-card"><span className="share-icon"><Stethoscope size={23} /></span><h2>Listo para la consulta</h2><p>Cuando haya datos podrás imprimir un resumen claro para comentarlo con el pediatra.</p><button onClick={() => window.print()} disabled={!entries.length}>Imprimir resumen</button></aside></div></section>;
}

function TrendsView({ profile, entries, now }: { profile: Profile; entries: Entry[]; now: number }) {
  const weekSleep = calculateWeekSleep(entries);
  const weekLabels = Array.from({ length: 7 }, (_, index) => new Intl.DateTimeFormat("es-ES", { weekday: "narrow" }).format(new Date(now - (6 - index) * 86_400_000)).toUpperCase());
  const sleepEntries = entries.filter((entry) => entry.kind === "sleep" && entry.durationMinutes);
  const feeds = entries.filter((entry) => entry.kind === "feed");
  const diapers = entries.filter((entry) => entry.kind === "diaper");
  const daysWithSleep = weekSleep.filter(Boolean);
  const averageSleep = daysWithSleep.length ? Math.round(daysWithSleep.reduce((total, value) => total + value, 0) / daysWithSleep.length) : 0;
  const averageNap = sleepEntries.length ? Math.round(sleepEntries.reduce((total, entry) => total + (entry.durationMinutes ?? 0), 0) / sleepEntries.length) : 0;
  const enoughData = sleepEntries.length >= 3;

  return <section className="page-view"><header className="page-header"><div><p className="eyebrow">Últimos 7 días</p><h1>Tendencias</h1></div></header><div className={`insight-hero ${enoughData ? "" : "learning"}`}><div><span className="insight-badge"><Sparkles size={14} /> {enoughData ? "Datos reales" : "Aprendiendo"}</span><h2>{enoughData ? `Ya podemos empezar a ver el ritmo de ${profile.babyName}.` : `Necesitamos al menos 3 sueños para encontrar patrones.`}</h2><p>Mostramos observaciones de vuestros registros, nunca recomendaciones médicas.</p></div><div className="big-stat"><strong>{sleepEntries.length}</strong><span>sueños registrados</span></div></div><div className="trends-grid"><section className="panel chart-card"><div className="panel-heading"><div><p className="eyebrow">Sueño diario</p><h2>{averageSleep ? `${formatMinutes(averageSleep)} de media` : "Sin datos todavía"}</h2></div></div><div className="bar-chart" aria-label="Sueño total de los últimos siete días">{weekSleep.map((value, index) => <div className="bar-column" key={`${weekLabels[index]}-${index}`}><div className="bar-track"><span style={{ height: `${Math.max(value ? 6 : 0, Math.min(100, (value / 900) * 100))}%` }} className={index === 6 ? "today" : ""} /></div><small>{weekLabels[index]}</small></div>)}</div></section><section className="panel rhythm-card"><div className="panel-heading"><div><p className="eyebrow">Actividad registrada</p><h2>Esta semana</h2></div></div><div className="real-totals"><div><Moon /><strong>{sleepEntries.length}</strong><span>sueños</span></div><div><Milk /><strong>{feeds.length}</strong><span>tomas</span></div><div><Droplets /><strong>{diapers.length}</strong><span>pañales</span></div></div></section></div><section className="panel pattern-list"><div className="panel-heading"><div><p className="eyebrow">Observaciones</p><h2>{entries.length ? "Lo que cuentan los datos" : "Todavía está todo por descubrir"}</h2></div></div>{entries.length ? <div className="pattern-grid"><div><Clock3 /><strong>Duración de sueño</strong><p>{averageNap ? `La duración media registrada es ${formatMinutes(averageNap)}.` : "Aún no hay sueños completos."}</p></div><div><Milk /><strong>Tomas</strong><p>{feeds.length ? `${feeds.length} tomas registradas en total.` : "Aún no hay tomas registradas."}</p></div><div><Droplets /><strong>Pañales</strong><p>{diapers.length ? `${diapers.length} cambios registrados en total.` : "Aún no hay cambios registrados."}</p></div></div> : <EmptyState icon={BarChart3} title="Sin datos de muestra" body="Las gráficas crecerán poco a poco con vuestra rutina real." />}</section></section>;
}

function SettingsView({ profile, onEdit }: { profile: Profile; onEdit: () => void }) {
  return <section className="page-view settings-view"><header className="page-header"><div><p className="eyebrow">Tu familia</p><h1>Ajustes</h1></div></header><section className="profile-card panel"><div className="large-avatar">{initials(profile.babyName)}</div><div><h2>{profile.babyName}</h2><p>{formatBirthDate(profile.birthDate)} · {ageLabel(profile)}</p></div><button onClick={onEdit}>Editar</button></section><section className="settings-group panel"><h2>Cuidado diario</h2><SettingRow icon={Bell} title="Avisos tranquilos" detail="Solo cuando realmente ayudan" /><SettingRow icon={Activity} title="Actividades visibles" detail="Sueño, tomas, pañales y salud" /><SettingRow icon={Baby} title="Cuidador principal" detail={`${profile.caregiverName} · Uso personal`} /></section><section className="settings-group panel"><h2>Salud y privacidad</h2><SettingRow icon={Stethoscope} title="Datos del pediatra" detail="Sin configurar" /><SettingRow icon={HeartPulse} title="Salud y crecimiento" detail="Disponible en próximos pasos" /><SettingRow icon={Settings} title="Tus datos" detail="Guardados en el espacio privado de Nido" /></section></section>;
}

function SettingRow({ icon: Icon, title, detail }: { icon: typeof Bell; title: string; detail: string }) { return <div className="setting-row"><span><Icon size={19} /></span><div><strong>{title}</strong><small>{detail}</small></div></div>; }

function ProfileSheet({ profile, onClose, onSave }: { profile: Profile; onClose: () => void; onSave: (profile: Profile) => Promise<Profile> }) {
  return <div className="sheet-backdrop"><button type="button" className="sheet-dismiss-layer" onClick={onClose} aria-label="Cerrar edición de perfil" /><section className="log-sheet profile-sheet" role="dialog" aria-modal="true" aria-labelledby="profile-title"><div className="sheet-handle" /><header><span className="event-icon sleep"><Baby size={20} /></span><div><p className="eyebrow">Tu familia</p><h2 id="profile-title">Editar perfil</h2></div><button className="circle-button" onClick={onClose} aria-label="Cerrar"><X size={19} /></button></header><ProfileForm profile={profile} onSave={onSave} submitLabel="Guardar cambios" /></section></div>;
}

function LogSheet({ kind, onClose, onAdd, onSleep, activeSleep }: { kind: EntryKind; onClose: () => void; onAdd: (entry: Omit<Entry, "id" | "occurredAt">) => Promise<void>; onSleep: () => void; activeSleep: number | null }) {
  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    if (kind === "feed") {
      const amountMl = Number(data.get("amount")) || null;
      void onAdd({ kind, title: String(data.get("feedType")), detail: `${amountMl ? `${amountMl} ml · ` : ""}${data.get("milkType")}`, amountMl, durationMinutes: null });
    }
    if (kind === "diaper") void onAdd({ kind, title: "Pañal", detail: String(data.get("diaperType")), durationMinutes: null, amountMl: null });
    if (kind === "health") void onAdd({ kind, title: String(data.get("careType")), detail: String(data.get("note") || "Sin notas"), durationMinutes: null, amountMl: null });
  }
  const config = labels[kind]; const Icon = config.icon;
  return <div className="sheet-backdrop"><button type="button" className="sheet-dismiss-layer" onClick={onClose} aria-label={`Cerrar registro de ${config.label.toLowerCase()}`} /><section className="log-sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title"><div className="sheet-handle" /><header><span className={`event-icon ${config.className}`}><Icon size={20} /></span><div><p className="eyebrow">Registrar ahora</p><h2 id="sheet-title">{config.label}</h2></div><button className="circle-button" onClick={onClose} aria-label="Cerrar"><X size={19} /></button></header>{kind === "sleep" ? <div className="sleep-sheet"><div className="sleep-sheet-orb"><Moon size={30} /></div><h3>{activeSleep ? "El sueño sigue en curso" : "¿Empezamos a contar?"}</h3><p>{activeSleep ? "Al terminar guardaremos la duración automáticamente." : "Puedes cerrar la app. El temporizador seguirá en este dispositivo."}</p><button className="sheet-submit" onClick={() => { onSleep(); onClose(); }}>{activeSleep ? "Terminar y guardar" : "Empezar sueño"}</button><button className="secondary-sheet-button" onClick={() => void onAdd({ kind: "sleep", title: "Sueño", detail: "45 min · Añadido manualmente", durationMinutes: 45, amountMl: null })}>Añadir sueño de 45 min</button></div> : <form onSubmit={submit}>{kind === "feed" && <><label>Tipo<select name="feedType"><option>Biberón</option><option>Pecho</option><option>Sólidos</option></select></label><div className="form-row"><label>Cantidad<div className="input-suffix"><input name="amount" type="number" inputMode="numeric" min="0" placeholder="120" /><span>ml</span></div></label><label>Contenido<select name="milkType"><option>Leche materna</option><option>Fórmula</option><option>Mixto</option><option>No indicado</option></select></label></div></>}{kind === "diaper" && <fieldset><legend>¿Cómo estaba?</legend><div className="choice-grid">{["Mojado", "Sucio", "Ambos", "Seco"].map((value) => <label key={value}><input type="radio" name="diaperType" value={value} defaultChecked={value === "Mojado"} /><span>{value}</span></label>)}</div></fieldset>}{kind === "health" && <><label>Actividad<select name="careType"><option>Baño</option><option>Temperatura</option><option>Medicación</option><option>Crecimiento</option><option>Hito</option></select></label><label>Nota<input name="note" placeholder="Añade un detalle, si quieres" /></label><div className="care-shortcuts"><Bath /><Thermometer /><Stethoscope /></div></>}<button className="sheet-submit" type="submit">Guardar</button></form>}</section></div>;
}
