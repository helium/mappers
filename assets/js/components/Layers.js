const DAY_S = 24 * 60 * 60

export const COLOR_BY_SIGNAL = 'signal'
export const COLOR_BY_LAST_HEARD = 'last_heard'

const signalColor = ['interpolate',
    ['linear'],
    ['get', 'best_rssi'],
    -120,
    'rgba(38,251,202,0.1)',
    -100,
    'rgba(38,251,202,0.45)',
    -80,
    'rgba(38,251,202,0.8)']

// Age ramp for the Last heard mode, shared with the legend. Bright mint through
// the first week, fading through teal and olive to a dim brown past two years.
// Each stop closes a legend bucket that runs from the previous stop up to it, so
// the swatch shows the color a hex reaches at the old end of its bucket.
export const lastHeardStops = [
    { days: 7, label: '< 1 wk', color: 'rgba(58,250,203,0.85)' },
    { days: 30, label: '1 wk–1 mo', color: 'rgba(47,164,139,0.75)' },
    { days: 90, label: '1–3 mo', color: 'rgba(122,140,92,0.65)' },
    { days: 180, label: '3–6 mo', color: 'rgba(150,116,64,0.55)' },
    { days: 365, label: '6–12 mo', color: 'rgba(130,98,57,0.5)' },
    { days: 730, label: '1 yr+', color: 'rgba(110,80,50,0.45)' }
]

// Legend buckets for the Signal mode, split halfway between the ramp stops so
// each swatch's color sits in the middle of its range.
export const signalBuckets = [
    { label: '< -110', className: 'legend-dBm-low', max: -110 },
    { label: '-110 to -90', className: 'legend-dBm-medium', min: -110, max: -90 },
    { label: '≥ -90', className: 'legend-dBm-high', min: -90 }
]

const lastHeardBuckets = lastHeardStops.map((stop, i) => ({
    min: i === 0 ? undefined : lastHeardStops[i - 1].days * DAY_S,
    // the last bucket is open-ended, its stop only sets the color
    max: i === lastHeardStops.length - 1 ? undefined : stop.days * DAY_S
}))

// last_heard is epoch seconds. Hexes without one get missingLastHeard, which
// is 0 (oldest) for tiles and now for live hexes, which were just heard.
const ageSeconds = (nowSeconds, missingLastHeard) =>
    ['-', nowSeconds, ['coalesce', ['get', 'last_heard'], missingLastHeard]]

const lastHeardColor = (nowSeconds, missingLastHeard) => [
    'interpolate',
    ['linear'],
    ageSeconds(nowSeconds, missingLastHeard),
    ...lastHeardStops.flatMap(stop => [stop.days * DAY_S, stop.color])
]

// Buckets are [min, max), so together they cover every value exactly once.
const rangeFilter = (value, { min, max }) => [
    'all',
    ...(min === undefined ? [] : [['>=', value, min]]),
    ...(max === undefined ? [] : [['<', value, max]])
]

// Keeps only the hexes in one legend bucket, or returns undefined for no filter.
const bucketFilter = (bucket, nowSeconds, missingLastHeard) => {
    if (!bucket) return undefined
    if (bucket.colorBy === COLOR_BY_LAST_HEARD) {
        return rangeFilter(ageSeconds(nowSeconds, missingLastHeard), lastHeardBuckets[bucket.index])
    }
    return rangeFilter(['coalesce', ['get', 'best_rssi'], -999], signalBuckets[bucket.index])
}

// only set filter when there is one, so the layer is added without a filter key
const withFilter = (layer, filter) => filter ? { ...layer, filter } : layer

const hexPaint = fillColor => ({
    'fill-color': [
        'case',
        ['boolean',
            ['feature-state', 'selected'], true],
        fillColor,
        '#b67ffe'
    ],
    'fill-opacity': 0.9,
    'fill-outline-color': [
        'case',
        ['boolean',
            ['feature-state', 'selected'], true],
        'rgba(38,251,202,0.45)',
        '#ffffff'
    ]
});

export const uplinkTileServerLayer = (colorBy, nowSeconds, legendBucket) => withFilter({
    id: 'public.h3_res9',
    type: 'fill',
    paint: hexPaint(colorBy === COLOR_BY_LAST_HEARD ? lastHeardColor(nowSeconds, 0) : signalColor)
}, bucketFilter(legendBucket, nowSeconds, 0));

export const hotspotTileServerLayer = {
    id: 'hg.gateways-rewarded-r8.hexes',
    type: 'fill',
    paint: {
        'fill-color': '#ffffff',
        'fill-outline-color': '#fafbfd',
        'fill-opacity': 0.15,
    }
};

export const uplinkHotspotsLineLayer = {
    id: 'uplinkHotspotsLineLayer',
    type: 'line',
    layout: {
        'line-join': 'round',
        'line-cap': 'round'
    },
    paint: {
        'line-color': '#d8d51d',
        'line-width': 2
    }
};

export const uplinkHotspotsCircleLayer = {
    id: 'uplinkHotspotsCircleLayer',
    type: 'circle',
    paint: {
        'circle-color': '#d8d51d',
    }
};

export const uplinkHotspotsHexLayer = {
    id: 'uplinkHotspotsHexLayer',
    type: 'fill',
    paint: {
        'fill-color': '#a5a308',
        'fill-outline-color': '#414a4a',
        'fill-opacity': 0.45,
    }
};

export const uplinkChannelLayer = (colorBy, nowSeconds, legendBucket) => withFilter({
    id: 'uplinkChannelLayer',
    type: 'fill',
    paint: hexPaint(colorBy === COLOR_BY_LAST_HEARD ? lastHeardColor(nowSeconds, nowSeconds) : signalColor)
}, bucketFilter(legendBucket, nowSeconds, nowSeconds));

export const selectedHotspotLayer = {
    id: 'selectedHotspotLayer',
    type: 'circle',
    paint: {
        'circle-color': '#ffffff',
        'circle-radius': 7,
        'circle-stroke-color': '#b67ffe',
        'circle-stroke-width': 3
    }
};
