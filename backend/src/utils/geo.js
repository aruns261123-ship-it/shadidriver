export function roundPaise(value) {
  return Math.round(value);
}

export function haversineMeters(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}

export function cityToCode(city) {
  const map = {
    delhi: 'DEL',
    'new delhi': 'DEL',
    ncr: 'DEL',
    'delhi ncr': 'DEL',
    gurgaon: 'DEL',
    gurugram: 'DEL',
    noida: 'DEL',
    jaipur: 'JAI',
    udaipur: 'UDR',
    mumbai: 'MUM',
    bangalore: 'BLR',
    bengaluru: 'BLR',
  };
  return map[String(city || '').trim().toLowerCase()] || 'DEL';
}

export function hoursBetween(start, end) {
  return Math.max(1, Math.ceil((new Date(end).getTime() - new Date(start).getTime()) / 3_600_000));
}

export function isNightWindow(start) {
  const hour = new Date(start).getHours();
  return hour >= 22 || hour < 6;
}

export function rangesOverlap(aStart, aEnd, bStart, bEnd) {
  return new Date(aStart).getTime() < new Date(bEnd).getTime() && new Date(bStart).getTime() < new Date(aEnd).getTime();
}
