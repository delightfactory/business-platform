export function nextConfigurationDate(value: string) {
  const date = new Date(`${value}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}

/** Finite ranges remain subject to the server's precise overlap check. */
export function configurationDateFloor(previous: string | undefined, openEndedMinimum: string | null | undefined, until: string) {
  const versionMinimum = previous ? nextConfigurationDate(previous) : '';
  return (until ? versionMinimum : [versionMinimum, openEndedMinimum ?? ''].sort().at(-1)) || undefined;
}
