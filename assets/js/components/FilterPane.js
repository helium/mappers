import React from 'react'
import { get } from '../data/Rest'
import { COLOR_BY_LAST_HEARD } from './Layers'

const SEARCH_DELAY_MS = 300

const DATE_PRESETS = [
    { label: 'All time', months: null },
    { label: 'Previous 3 months', months: 3 },
    { label: 'Previous 6 months', months: 6 },
    { label: 'Previous 12 months', months: 12 },
    { label: 'Previous 24 months', months: 24 },
]

// UTC to match the date inputs; setUTCMonth clamps overflow, e.g. May 31 minus 3 months is Mar 3
const monthsAgo = months => {
    const date = new Date()
    date.setUTCMonth(date.getUTCMonth() - months)
    return date.toISOString().slice(0, 10)
}

const presetStart = preset => preset.months === null ? '' : monthsAgo(preset.months)

// names are stored kebab-case, but people type them the way the hex pane shows them
const toHotspotName = value => value.trim().toLowerCase().replace(/\s+/g, '-')

const fetchHotspots = query =>
    get('hotspots?q=' + encodeURIComponent(query))
        .then(res => {
            if (res.status == 429) throw new Error('Too many requests, try again in a minute')
            if (!res.ok) throw new Error('Hotspot search failed')
            return res.json()
        })
        .then(body => body.hotspots)

function FilterPane(props) {
    const { colorBy, filters, onFiltersChange, onHotspotSelect } = props
    const [hotspotQuery, setHotspotQuery] = React.useState(filters.hotspot)
    const [suggestions, setSuggestions] = React.useState([])
    const [searchError, setSearchError] = React.useState(null)
    // separate from searchError so a suggestions request finishing late can't clear it
    const [enterError, setEnterError] = React.useState(null)

    // keep the input in sync when a hotspot is picked from the hex pane
    React.useEffect(() => setHotspotQuery(filters.hotspot), [filters.hotspot])

    React.useEffect(() => {
        const query = hotspotQuery.trim()
        if (query.length < 2 || query === filters.hotspot) {
            setSuggestions([])
            return
        }

        let cancelled = false
        const timer = setTimeout(() => {
            fetchHotspots(query)
                .then(hotspots => {
                    if (cancelled) return
                    setSearchError(null)
                    setSuggestions(hotspots)
                })
                .catch(err => {
                    if (!cancelled) setSearchError(err.message)
                })
        }, SEARCH_DELAY_MS)

        return () => {
            cancelled = true
            clearTimeout(timer)
        }
    }, [hotspotQuery, filters.hotspot])

    const onHotspotInput = event => {
        const value = event.target.value
        setHotspotQuery(value)
        setEnterError(null)
        const match = suggestions.find(h => h.name === value)
        if (match) onHotspotSelect(match)
        else if (value === '') onFiltersChange({ ...filters, hotspot: '' })
    }

    // Enter applies an exact name match, or the only match when the text is a prefix of one hotspot
    const onHotspotKeyDown = event => {
        if (event.key !== 'Enter') return
        event.preventDefault()
        const name = toHotspotName(hotspotQuery)
        if (name.length < 2) return

        fetchHotspots(name)
            .then(hotspots => {
                const match = hotspots.find(h => h.name === name) || (hotspots.length === 1 ? hotspots[0] : null)
                if (match) {
                    setEnterError(null)
                    setSuggestions([])
                    onHotspotSelect(match)
                } else if (hotspots.length === 0) {
                    setEnterError('No hotspot named "' + hotspotQuery.trim() + '"')
                } else {
                    setSuggestions(hotspots)
                    setEnterError(hotspots.length + ' hotspots start with "' + hotspotQuery.trim() + '", pick one from the list')
                }
            })
            .catch(err => setEnterError(err.message))
    }

    const rangeError = filters.start && filters.end && filters.start > filters.end
        ? 'Start date must be on or before end date'
        : null

    const isActive = filters.start || filters.end || filters.hotspot
    const activePreset = filters.end ? null : DATE_PRESETS.find(p => presetStart(p) === filters.start)

    return (
        <div className="filter-pane">
            <div className="filter-presets" role="group" aria-label="Date range presets">
                {DATE_PRESETS.map(preset => (
                    <button
                        key={preset.label}
                        className={'filter-preset' + (preset === activePreset ? ' is-active' : '')}
                        aria-pressed={preset === activePreset}
                        onClick={() => onFiltersChange({ ...filters, start: presetStart(preset), end: '' })}
                    >
                        {preset.label}
                    </button>
                ))}
            </div>
            <div className="filter-row">
                <label className="filter-field">
                    <span className="type-smallcap">Heard from</span>
                    <input
                        type="date"
                        value={filters.start}
                        max={filters.end || undefined}
                        onChange={e => onFiltersChange({ ...filters, start: e.target.value })}
                    />
                </label>
                <label className="filter-field">
                    <span className="type-smallcap">Heard through</span>
                    <input
                        type="date"
                        value={filters.end}
                        min={filters.start || undefined}
                        onChange={e => onFiltersChange({ ...filters, end: e.target.value })}
                    />
                </label>
            </div>
            <label className="filter-field">
                <span className="type-smallcap">Hotspot</span>
                <input
                    type="search"
                    list="hotspot-suggestions"
                    placeholder="Hotspot name, then Enter"
                    value={hotspotQuery}
                    onChange={onHotspotInput}
                    onKeyDown={onHotspotKeyDown}
                />
                <datalist id="hotspot-suggestions">
                    {suggestions.map(h => <option key={h.name} value={h.name} />)}
                </datalist>
            </label>
            {(rangeError || enterError || searchError) &&
                <div className="filter-error">{rangeError || enterError || searchError}</div>
            }
            <div className="filter-footer">
                <span className="filter-note">
                    Dates are UTC. Hexes are colored by {colorBy === COLOR_BY_LAST_HEARD ? 'the latest uplink' : 'the best RSSI'} heard within the filter.
                </span>
                {isActive &&
                    <button className="filter-clear" onClick={() => onFiltersChange({ start: '', end: '', hotspot: '' })}>
                        Clear
                    </button>
                }
            </div>
        </div>
    )
}

export default FilterPane
