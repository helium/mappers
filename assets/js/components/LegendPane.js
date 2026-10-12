import React from 'react'
import classNames from 'classnames'
import { COLOR_BY_SIGNAL, COLOR_BY_LAST_HEARD, lastHeardStops, signalBuckets } from './Layers'

const HEX_PATH = "M7 0L13.0622 3.5V10.5L7 14L0.937822 10.5V3.5L7 0Z"

// Tapping or clicking a button doesn't match :focus-visible, so this tells
// keyboard focus apart from the focus a tap gives on some mobile browsers.
const isKeyboardFocus = el => el.matches(':focus-visible')

function LegendPane(props) {
    const { colorBy, onColorByChange, onBucketChange } = props
    // preview follows the mouse or keyboard focus, pinned is toggled by a click or tap
    const [preview, setPreview] = React.useState(null)
    const [pinned, setPinned] = React.useState(null)
    const active = preview !== null ? preview : pinned

    React.useEffect(() => {
        onBucketChange(active === null ? null : { colorBy, index: active })
    }, [colorBy, active])

    // closing the legend shows the whole map again
    React.useEffect(() => () => onBucketChange(null), [])

    // bucket indexes belong to one color mode
    const changeColorBy = value => {
        setPreview(null)
        setPinned(null)
        onColorByChange(value)
    }

    const bucketProps = (index, description) => ({
        className: classNames("legend-item legend-bucket", { "is-active": active === index }),
        title: 'Show only hexes ' + description,
        'aria-pressed': pinned === index,
        onPointerEnter: e => { if (e.pointerType === 'mouse') setPreview(index) },
        onPointerLeave: e => { if (e.pointerType === 'mouse') setPreview(null) },
        onFocus: e => { if (isKeyboardFocus(e.target)) setPreview(index) },
        onBlur: () => setPreview(null),
        onClick: () => setPinned(pinned === index ? null : index)
    })

    return (
        <div className="legend">
            <div className="legend-line color-by" role="radiogroup" aria-label="Color hexes by">
                <span className="legend-item type-smallcap">Color by</span>
                {[[COLOR_BY_SIGNAL, 'Signal'], [COLOR_BY_LAST_HEARD, 'Last heard']].map(([value, label]) =>
                    <button
                        key={value}
                        role="radio"
                        aria-checked={colorBy === value}
                        className={classNames("color-by-option", { "is-active": colorBy === value })}
                        onClick={() => changeColorBy(value)}
                    >
                        {label}
                    </button>
                )}
            </div>

            {colorBy === COLOR_BY_SIGNAL &&
            <div className={classNames("legend-line legend-buckets", { "has-active": active !== null })} role="group" aria-label="Show only hexes with this best RSSI">
                <span className="legend-item type-smallcap">RSSI</span>
                {signalBuckets.map((bucket, i) =>
                    <button key={bucket.label} {...bucketProps(i, 'with a best RSSI of ' + bucket.label + ' dBm')}>
                        <svg className={"legend-icon " + bucket.className} width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                            <path d={HEX_PATH} />
                        </svg>
                        <span>{bucket.label}<span className="stat-unit"> dBm</span></span>
                    </button>
                )}
            </div>
            }

            {colorBy === COLOR_BY_LAST_HEARD &&
            <div className={classNames("legend-line legend-buckets", { "has-active": active !== null })} role="group" aria-label="Show only hexes last heard this long ago">
                <span className="legend-item type-smallcap">Age</span>
                {lastHeardStops.map((stop, i) =>
                    <button key={stop.days} {...bucketProps(i, 'last heard ' + stop.label + ' ago')}>
                        <svg className="legend-icon" style={{ fill: stop.color }} width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                            <path d={HEX_PATH} />
                        </svg>
                        <span>{stop.label}</span>
                    </button>
                )}
            </div>
            }

            <div className="legend-line">
                <div className="legend-item">
                    <svg className="legend-icon legend-mapper-witness" width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                        <path d={HEX_PATH} />
                    </svg>
                    <span>Mapper Witness</span>
                </div>
            </div>

            <div className="legend-line">
                <div className="legend-item">
                    <svg className="legend-icon legend-hotspot" width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                        <path d={HEX_PATH} />
                    </svg>
                    <span>Hotspot</span>
                </div>
            </div>
        </div>
    )
}

export default LegendPane
