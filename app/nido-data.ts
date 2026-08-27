export type EntryKind = "sleep" | "feed" | "diaper" | "health";

export type Profile = {
  caregiverName: string;
  babyName: string;
  birthDate: string;
};

export type Entry = {
  id: string;
  kind: EntryKind;
  title: string;
  detail: string;
  occurredAt: number;
  durationMinutes: number | null;
  amountMl: number | null;
};

export type DayMetrics = {
  sleepMinutes: number;
  feeds: number;
  feedMl: number;
  diapers: number;
};

export function startOfDay(timestamp: number) {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function entriesForDay(entries: Entry[], timestamp: number) {
  const start = startOfDay(timestamp);
  const end = start + 86_400_000;
  return entries.filter((entry) => entry.occurredAt >= start && entry.occurredAt < end);
}

export function calculateDayMetrics(entries: Entry[], timestamp = Date.now()): DayMetrics {
  return entriesForDay(entries, timestamp).reduce<DayMetrics>((metrics, entry) => {
    if (entry.kind === "sleep") metrics.sleepMinutes += entry.durationMinutes ?? 0;
    if (entry.kind === "feed") {
      metrics.feeds += 1;
      metrics.feedMl += entry.amountMl ?? 0;
    }
    if (entry.kind === "diaper") metrics.diapers += 1;
    return metrics;
  }, { sleepMinutes: 0, feeds: 0, feedMl: 0, diapers: 0 });
}

export function calculateWeekSleep(entries: Entry[], timestamp = Date.now()) {
  const today = startOfDay(timestamp);
  return Array.from({ length: 7 }, (_, index) => {
    const day = today - (6 - index) * 86_400_000;
    return calculateDayMetrics(entries, day).sleepMinutes;
  });
}

export function ageInMonths(birthDate: string, now = new Date()) {
  const birth = new Date(`${birthDate}T12:00:00`);
  let months = (now.getFullYear() - birth.getFullYear()) * 12 + now.getMonth() - birth.getMonth();
  if (now.getDate() < birth.getDate()) months -= 1;
  return Math.max(0, months);
}

export function wakeWindowMinutes(months: number) {
  if (months < 2) return 60;
  if (months < 4) return 90;
  if (months < 6) return 105;
  if (months < 9) return 150;
  return 180;
}

export function formatMinutes(minutes: number) {
  if (!minutes) return "0 min";
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return hours ? `${hours} h${rest ? ` ${rest} min` : ""}` : `${rest} min`;
}
