import React from 'react'

const MAPBOX_TOKEN = process.env.PUBLIC_MAPBOX_KEY
const GEOCODING_URL = 'https://api.mapbox.com/geocoding/v5/mapbox.places/'
const SEARCH_DELAY_MS = 300
// every request is billed against the public token, so skip one- and two-letter queries
const MIN_QUERY_LENGTH = 3
const LISTBOX_ID = 'location-search-results'

const optionId = index => LISTBOX_ID + '-' + index

const geocode = (query, center, signal) => {
    const params = new URLSearchParams({ access_token: MAPBOX_TOKEN })
    if (center) params.set('proximity', center.longitude.toFixed(4) + ',' + center.latitude.toFixed(4))

    return fetch(GEOCODING_URL + encodeURIComponent(query) + '.json?' + params.toString(), { signal })
        .then(res => {
            if (res.status == 429) throw new Error('Too many searches, try again in a minute')
            if (res.status == 401 || res.status == 403) throw new Error('Location search is unavailable right now')
            if (!res.ok) throw new Error('Location search failed, try again')
            return res.json()
        })
        .then(body => body.features || [])
}

function LocationSearch(props) {
    const { center, onPlaceSelect } = props
    const [query, setQuery] = React.useState('')
    const [results, setResults] = React.useState([])
    const [status, setStatus] = React.useState('idle')
    const [error, setError] = React.useState(null)
    const [open, setOpen] = React.useState(false)
    const [activeIndex, setActiveIndex] = React.useState(-1)
    // the label of the place last picked, so filling the input with it does not search again
    const [selectedName, setSelectedName] = React.useState(null)

    // read at request time, so panning the map does not trigger a new search
    const centerRef = React.useRef(center)
    centerRef.current = center

    React.useEffect(() => {
        const trimmed = query.trim()
        if (trimmed.length < MIN_QUERY_LENGTH || query === selectedName) {
            setResults([])
            setStatus('idle')
            setError(null)
            return
        }
        if (!MAPBOX_TOKEN) {
            setStatus('error')
            setError('Location search is not configured')
            return
        }

        // loading right away, so Enter can't pick a result for the previous query
        setStatus('loading')
        // the cleanup aborts the in-flight request, so a slow response for an
        // older query can never replace newer results
        const controller = new AbortController()
        const timer = setTimeout(() => {
            geocode(trimmed, centerRef.current, controller.signal)
                .then(features => {
                    setResults(features)
                    setActiveIndex(-1)
                    setError(null)
                    setStatus(features.length ? 'done' : 'empty')
                })
                .catch(err => {
                    if (err.name === 'AbortError') return
                    setResults([])
                    setError(err instanceof TypeError ? 'Could not reach the location service' : err.message)
                    setStatus('error')
                })
        }, SEARCH_DELAY_MS)

        return () => {
            clearTimeout(timer)
            controller.abort()
        }
    }, [query, selectedName])

    const select = place => {
        setSelectedName(place.place_name)
        setQuery(place.place_name)
        setResults([])
        setOpen(false)
        setActiveIndex(-1)
        onPlaceSelect(place)
    }

    const onChange = event => {
        setQuery(event.target.value)
        setOpen(true)
    }

    const onKeyDown = event => {
        const count = results.length
        switch (event.key) {
            case 'ArrowDown':
                event.preventDefault()
                if (!count) return
                setOpen(true)
                setActiveIndex(open ? (activeIndex + 1) % count : 0)
                break
            case 'ArrowUp':
                event.preventDefault()
                if (!count) return
                setOpen(true)
                setActiveIndex(open && activeIndex > 0 ? activeIndex - 1 : count - 1)
                break
            case 'Enter':
                if (open && count && status === 'done') {
                    event.preventDefault()
                    select(results[activeIndex >= 0 ? activeIndex : 0])
                }
                break
            case 'Escape':
                if (open) {
                    event.preventDefault()
                    setOpen(false)
                    setActiveIndex(-1)
                } else if (query) {
                    event.preventDefault()
                    setQuery('')
                    setSelectedName(null)
                }
                break
        }
    }

    const showList = open && results.length > 0
    const message = open && (status === 'error' ? error
        : status === 'empty' ? 'No places match "' + query.trim() + '"'
        : status === 'loading' && !results.length ? 'Searching…'
        : null)

    return (
        <div className="filter-pane">
            <div className="filter-field">
                <label className="type-smallcap" htmlFor="location-search-input">Go to a place</label>
                <div className="location-search-box">
                    <input
                        id="location-search-input"
                        autoFocus
                        type="search"
                        role="combobox"
                        autoComplete="off"
                        spellCheck="false"
                        placeholder="Address, city, or landmark"
                        aria-autocomplete="list"
                        aria-expanded={showList}
                        aria-controls={LISTBOX_ID}
                        aria-activedescendant={showList && activeIndex >= 0 ? optionId(activeIndex) : undefined}
                        aria-describedby="location-search-status"
                        value={query}
                        onChange={onChange}
                        onKeyDown={onKeyDown}
                        onFocus={() => setOpen(true)}
                        onBlur={() => setOpen(false)}
                    />
                    <ul id={LISTBOX_ID} role="listbox" aria-label="Places" className="location-results" hidden={!showList}>
                        {showList && results.map((place, i) => (
                            <li
                                key={place.id}
                                id={optionId(i)}
                                role="option"
                                aria-selected={i === activeIndex}
                                className={'location-result' + (i === activeIndex ? ' active' : '')}
                                // mousedown would blur the input and close the list before the click lands
                                onMouseDown={e => e.preventDefault()}
                                onMouseEnter={() => setActiveIndex(i)}
                                onClick={() => select(place)}
                            >
                                <span className="location-result-name">{place.text}</span>
                                <span className="location-result-context">{place.place_name}</span>
                            </li>
                        ))}
                    </ul>
                </div>
            </div>
            <div
                id="location-search-status"
                role="status"
                className={'location-status ' + (status === 'error' ? 'filter-error' : 'filter-note')}
            >
                {message}
            </div>
        </div>
    )
}

export default LocationSearch
