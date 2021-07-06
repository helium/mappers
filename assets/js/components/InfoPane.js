import React from 'react'
import classNames from 'classnames'
import formatDistanceToNowStrict from 'date-fns/formatDistanceToNowStrict'
import parseISO from 'date-fns/parseISO'
import h3 from 'h3-js/dist/h3-js';

function InfoPane(props) {
    const [showLegendPane, setShowLegendPane] = React.useState(false)
    const onLegendClick = () => setShowLegendPane(!showLegendPane)

    function hotspotCount() {
        return props.uplinks.length
    }

    function recentTime() {
        let sortedTimes = props.uplinks;
        sortedTimes.sort((a,b) => -a.timestamp.localeCompare(b.timestamp))

        let distTimeFull = formatDistanceToNowStrict(parseISO(sortedTimes[0].timestamp))
        
        let distTimeValue = distTimeFull.split(" ")[0]; //get the value e.g. "3 hours" => "3"
        
        let distTimeUnit = distTimeFull.split(" ")[1]; //get the unit e.g. "3 hours" => "hours"
        let distTimeUnitUppercase = distTimeUnit.charAt(0).toUpperCase() + distTimeUnit.slice(1);

        let timeInfo = {
            full: distTimeFull,
            number: distTimeValue,
            unit: distTimeUnitUppercase
        }
        return timeInfo
    }

    function uplinkDistance(uplinkLat, uplinkLng) {
        // hotspots are res8, find the parent res8 from the res9 selected hex  
        let selectedHex = h3.h3ToParent(props.hexId, 8); 
        // Create the res8 from provided coordinates
        let hotspotHex = h3.geoToH3(uplinkLat, uplinkLng, 8);

        // if the mapped hex is within the hotspot hex return a null result.
        if (selectedHex == hotspotHex) {
            let result = {
                number: "–",
                unit: ""
            }
            return result
        }
        else { //compute the distance
            let point1 = [uplinkLat, uplinkLng];
            let point2 = h3.h3ToGeo(props.hexId);
            let distMi = h3.pointDist(point1, point2, h3.UNITS.km)/1.609;
            if (distMi < 1) {
                let result = {
                    number: distMi.toFixed(1),
                    unit: "mi"
                }
                return result
            }
            else {
                let result = {
                    number: Math.round(distMi),
                    unit: "mi"
                }
                return result
            }
        }
    }

    function deKebab(string){
        return string
        .split('-')
        .map((s) => s.charAt(0).toUpperCase() + s.substring(1))
        .join(' ');
    }

    return (
        <div className="info-pane">
            <div className={classNames("pane-nav", {
                 "has-subcontent": showLegendPane || props.showHexPane
            })}>
                <svg className="mappers-logo" xmlns="http://www.w3.org/2000/svg" width="97" height="24" viewBox="0 0 97 24">
                    <path fillRule="evenodd" clipRule="evenodd" d="M12 0C18.6274 0 24 5.37257 24 12C24 18.6274 18.6274 24 12 24C5.37257 24 0 18.6274 0 12C0 5.37257 5.37257 0 12 0ZM18.3937 9.44629C18.6933 9.14655 18.9186 8.78087 19.0515 8.37848C19.1844 7.97609 19.2213 7.54818 19.1593 7.12897C19.0972 6.70976 18.9379 6.3109 18.6941 5.9643C18.4502 5.61769 18.1287 5.33297 17.7551 5.13291C17.3815 4.93284 16.9663 4.82299 16.5426 4.81214C16.119 4.80129 15.6987 4.88975 15.3154 5.07043C14.9321 5.25111 14.5963 5.519 14.3351 5.85267C14.0738 6.18634 13.8943 6.57652 13.8109 6.992C11.8886 6.268 9.68286 6.728 8.21486 8.19657C6.74514 9.66571 6.28571 11.8737 7.012 13.7983C6.52886 13.8936 6.08074 14.1186 5.71561 14.449C5.35048 14.7794 5.08208 15.203 4.93915 15.6742C4.79622 16.1455 4.78413 16.6467 4.90418 17.1243C5.02424 17.6019 5.27191 18.0379 5.62069 18.3855C5.96947 18.7332 6.40623 18.9795 6.88421 19.098C7.3622 19.2165 7.86341 19.2028 8.33421 19.0583C8.805 18.9139 9.22765 18.6441 9.55691 18.2779C9.88617 17.9117 10.1097 17.4629 10.2034 16.9794C11.1524 17.3319 12.1824 17.405 13.1716 17.1902C14.1609 16.9754 15.0678 16.4817 15.7851 15.7674C17.248 14.304 17.7109 12.1091 16.9977 10.1909C17.5269 10.0875 18.0131 9.82816 18.3937 9.44629ZM15.1897 6.24229C15.5262 5.90639 15.9823 5.71774 16.4577 5.71774C16.9332 5.71774 17.3892 5.90639 17.7257 6.24229C18.0616 6.57889 18.2503 7.03502 18.2503 7.51057C18.2503 7.98613 18.0616 8.44225 17.7257 8.77886C17.5293 8.97673 17.2892 9.12569 17.0247 9.21373C16.7602 9.30177 16.4787 9.32643 16.2029 9.28572C16.1765 9.28227 16.1498 9.28227 16.1234 9.28572C15.9147 9.25829 15.7028 9.30322 15.5231 9.41302C15.3435 9.52281 15.2068 9.69085 15.136 9.88914C15.0566 10.1103 15.0606 10.3606 15.1669 10.5903C15.4602 11.2285 15.5514 11.9411 15.4284 12.6327C15.3053 13.3242 14.9738 13.9616 14.4783 14.4594C13.9804 14.9552 13.3428 15.2868 12.651 15.4099C11.9592 15.533 11.2464 15.4416 10.608 15.148C10.4974 15.0967 10.3777 15.0678 10.2559 15.0631C10.1341 15.0584 10.0125 15.0779 9.89829 15.1206C9.71077 15.1897 9.55083 15.318 9.44259 15.486C9.33436 15.654 9.28371 15.8527 9.29829 16.052C9.29368 16.0825 9.29368 16.1135 9.29829 16.144C9.34476 16.4257 9.32355 16.7143 9.23641 16.9862C9.14927 17.2581 8.9987 17.5053 8.79714 17.7074C8.46049 18.043 8.00451 18.2315 7.52914 18.2315C7.05378 18.2315 6.5978 18.043 6.26114 17.7074C6.09405 17.5413 5.96156 17.3437 5.87132 17.1261C5.78108 16.9084 5.73489 16.675 5.73543 16.4394C5.73543 15.9606 5.92229 15.5097 6.26114 15.1709C6.66343 14.7686 7.21886 14.584 7.81257 14.6651C7.87257 14.6771 7.93314 14.6857 7.99486 14.6857C8.18221 14.6858 8.36515 14.6289 8.51931 14.5224C8.67346 14.4159 8.79151 14.265 8.85771 14.0897C8.94343 13.8651 8.94172 13.608 8.83314 13.3731C8.53976 12.7348 8.44849 12.0221 8.57156 11.3305C8.69463 10.6388 9.02615 10.0013 9.52172 9.50343C10.0196 9.00768 10.6572 8.67603 11.349 8.55295C12.0408 8.42988 12.7536 8.52127 13.392 8.81486C13.6234 8.92229 13.8771 8.92571 14.0994 8.84343C14.3046 8.76842 14.4765 8.62296 14.5844 8.433C14.6923 8.24305 14.7292 8.02094 14.6886 7.80629C14.642 7.52453 14.6631 7.23572 14.7502 6.96376C14.8374 6.69179 14.988 6.44448 15.1897 6.24229ZM13.4183 13.3994C13.6057 13.2156 13.7547 12.9964 13.8569 12.7546C13.9591 12.5128 14.0123 12.2532 14.0136 11.9907C14.0148 11.7282 13.964 11.468 13.8641 11.2253C13.7643 10.9825 13.6173 10.762 13.4317 10.5763C13.246 10.3907 13.0255 10.2437 12.7827 10.1439C12.54 10.044 12.2798 9.99319 12.0173 9.99443C11.7548 9.99567 11.4952 10.0489 11.2534 10.1511C11.0116 10.2533 10.7924 10.4023 10.6086 10.5897C10.2465 10.9644 10.046 11.4663 10.0504 11.9873C10.0548 12.5084 10.2637 13.0068 10.6321 13.3753C11.0005 13.7438 11.499 13.9528 12.02 13.9573C12.541 13.9618 13.043 13.7615 13.4177 13.3994H13.4183Z" />
                    <path d="M28.6143 16.5H31.1557V10.9994C31.1557 9.98523 31.8001 9.31108 32.6472 9.31108C33.4824 9.31108 34.0432 9.88381 34.0432 10.7847V16.5H36.5072V10.904C36.5072 9.9554 37.0501 9.31108 37.9748 9.31108C38.7861 9.31108 39.3947 9.81818 39.3947 10.8384V16.5H41.9302V10.3372C41.9302 8.35057 40.7489 7.21705 39.0427 7.21705C37.7003 7.21705 36.6563 7.90312 36.2805 8.95312H36.185C35.8927 7.89119 34.956 7.21705 33.6972 7.21705C32.4623 7.21705 31.5256 7.8733 31.1438 8.95312H31.0364V7.33636H28.6143V16.5Z" />
                    <path d="M46.0468 16.673C47.401 16.673 48.278 16.0824 48.7255 15.2293H48.797V16.5H51.2073V10.3193C51.2073 8.1358 49.3578 7.21705 47.3175 7.21705C45.122 7.21705 43.6783 8.26704 43.3263 9.9375L45.6769 10.1284C45.8499 9.51989 46.3928 9.07244 47.3056 9.07244C48.1706 9.07244 48.6658 9.50795 48.6658 10.2597V10.2955C48.6658 10.8861 48.0394 10.9636 46.4465 11.1187C44.6328 11.2858 43.0042 11.8943 43.0042 13.9406C43.0042 15.7543 44.2988 16.673 46.0468 16.673ZM46.7746 14.919C45.9931 14.919 45.4323 14.5551 45.4323 13.8571C45.4323 13.1412 46.0229 12.7892 46.9178 12.6639C47.4726 12.5864 48.3794 12.4551 48.6837 12.2523V13.2247C48.6837 14.1852 47.8902 14.919 46.7746 14.919Z" />
                    <path d="M52.675 19.9364H55.2165V15.0324H55.294C55.646 15.796 56.4156 16.6491 57.8952 16.6491C59.9832 16.6491 61.6119 14.9966 61.6119 11.9301C61.6119 8.78011 59.9117 7.21705 57.9011 7.21705C56.3679 7.21705 55.6341 8.12983 55.294 8.87557H55.1807V7.33636H52.675V19.9364ZM55.1628 11.9182C55.1628 10.2835 55.8548 9.23949 57.0898 9.23949C58.3486 9.23949 59.0168 10.3312 59.0168 11.9182C59.0168 13.517 58.3367 14.6267 57.0898 14.6267C55.8668 14.6267 55.1628 13.5528 55.1628 11.9182Z" />
                    <path d="M62.8023 19.9364H65.3437V15.0324H65.4213C65.7733 15.796 66.5429 16.6491 68.0224 16.6491C70.1105 16.6491 71.7392 14.9966 71.7392 11.9301C71.7392 8.78011 70.0389 7.21705 68.0284 7.21705C66.4952 7.21705 65.7613 8.12983 65.4213 8.87557H65.3079V7.33636H62.8023V19.9364ZM65.29 11.9182C65.29 10.2835 65.9821 9.23949 67.217 9.23949C68.4758 9.23949 69.144 10.3312 69.144 11.9182C69.144 13.517 68.4639 14.6267 67.217 14.6267C65.994 14.6267 65.29 13.5528 65.29 11.9182Z" />
                    <path d="M77.1056 16.679C79.3727 16.679 80.9 15.5753 81.2579 13.875L78.9074 13.7199C78.6508 14.4179 77.9946 14.7818 77.1474 14.7818C75.8767 14.7818 75.0713 13.9406 75.0713 12.5744V12.5685H81.3116V11.8705C81.3116 8.75625 79.4264 7.21705 77.0042 7.21705C74.3076 7.21705 72.5596 9.1321 72.5596 11.9599C72.5596 14.8653 74.2838 16.679 77.1056 16.679ZM75.0713 10.9935C75.125 9.94943 75.9184 9.1142 77.046 9.1142C78.1497 9.1142 78.9133 9.9017 78.9193 10.9935H75.0713Z" />
                    <path d="M82.4661 16.5H85.0076V11.3156C85.0076 10.1881 85.8309 9.4125 86.9525 9.4125C87.3045 9.4125 87.7877 9.47216 88.0264 9.54972V7.2946C87.7997 7.24091 87.4835 7.20511 87.2269 7.20511C86.2008 7.20511 85.3596 7.8017 85.0255 8.93523H84.9301V7.33636H82.4661V16.5Z" />
                    <path d="M96.4608 9.94943C96.2341 8.26108 94.8739 7.21705 92.5591 7.21705C90.2145 7.21705 88.6693 8.30284 88.6753 10.0687C88.6693 11.4409 89.5344 12.3298 91.3241 12.6878L92.9111 13.004C93.7105 13.1651 94.0744 13.4574 94.0864 13.9168C94.0744 14.4597 93.4838 14.8474 92.5949 14.8474C91.6881 14.8474 91.0855 14.4597 90.9304 13.7139L88.4307 13.8452C88.6693 15.5991 90.1608 16.679 92.5889 16.679C94.9633 16.679 96.6636 15.4679 96.6696 13.6602C96.6636 12.3358 95.7986 11.5423 94.0207 11.1784L92.3622 10.8443C91.5091 10.6594 91.1929 10.367 91.1989 9.92557C91.1929 9.3767 91.8133 9.01875 92.6008 9.01875C93.4838 9.01875 94.0088 9.50199 94.1341 10.0926L96.4608 9.94943Z" />
                </svg>
                <ul className="nav-links">
                    <li className="nav-link">
                        <button onClick={onLegendClick}>Legend</button>
                    </li>
                    <li className="nav-link">
                        <a href="https://docs.helium.com/use-the-network/coverage-mapping" target="_blank">Docs</a>
                    </li>
                    <li className="nav-link">
                        <a href="https://github.com/helium/mappers" target="_blank">GitHub</a>
                    </li>
                </ul>
            </div>
            { showLegendPane &&
                <div className="legend">
                    <div className="legend-line">
                        <span className="legend-item type-smallcap">RSSI</span>
                        <div className="legend-item">
                            <svg className="legend-icon legend-dBm-low" width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                                <path d="M7 0L13.0622 3.5V10.5L7 14L0.937822 10.5V3.5L7 0Z" />
                            </svg>
                            <span>-120<span className="stat-unit"> dBm</span></span>
                        </div>
                        <div className="legend-item">
                            <svg className="legend-icon legend-dBm-medium" width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                                <path d="M7 0L13.0622 3.5V10.5L7 14L0.937822 10.5V3.5L7 0Z" />
                            </svg>
                            <span>-100<span className="stat-unit"> dBm</span></span>
                        </div>
                        <div className="legend-item">
                            <svg className="legend-icon legend-dBm-high" width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                                <path d="M7 0L13.0622 3.5V10.5L7 14L0.937822 10.5V3.5L7 0Z" />
                            </svg>
                            <span>-80<span className="stat-unit"> dBm</span></span>
                        </div>
                    </div>

                    <div className="legend-line">
                        <div className="legend-item">
                            <svg className="legend-icon legend-mapper-witness" width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                                <path d="M7 0L13.0622 3.5V10.5L7 14L0.937822 10.5V3.5L7 0Z" />
                            </svg>
                            <span>Mapper Witness</span>
                        </div>
                    </div>

                    <div className="legend-line">
                        <div className="legend-item">
                            <svg className="legend-icon legend-hotspot" width="14" height="14" viewBox="0 0 14 14" xmlns="http://www.w3.org/2000/svg">
                                <path d="M7 0L13.0622 3.5V10.5L7 14L0.937822 10.5V3.5L7 0Z" />
                            </svg>
                            <span>Hotspot</span>
                        </div>
                    </div>
                </div>
            }
            { props.showHexPane &&
                <div className="main-stats">
                    <div className="stats-heading">
                        <span>Hex Statistics</span>
                        <button className="close-button" onClick={props.onCloseHexPaneClick}>
                            <svg className="icon" width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
                                <path d="M7.9998 6.54957L13.4284 1.12096C13.8289 0.720422 14.4783 0.720422 14.8789 1.12096C15.2794 1.5215 15.2794 2.1709 14.8789 2.57144L9.45028 8.00004L14.8789 13.4287C15.2794 13.8292 15.2794 14.4786 14.8789 14.8791C14.4783 15.2797 13.8289 15.2797 13.4284 14.8791L7.9998 9.45052L2.57119 14.8791C2.17065 15.2797 1.52125 15.2797 1.12072 14.8791C0.720178 14.4786 0.720178 13.8292 1.12072 13.4287L6.54932 8.00004L1.12072 2.57144C0.720178 2.1709 0.720178 1.5215 1.12072 1.12096C1.52125 0.720422 2.17065 0.720422 2.57119 1.12096L7.9998 6.54957Z" />
                            </svg>
                        </button>
                    </div>
                    <div className="h3-holder">
                        <svg className="hex-icon" width="22" height="24" viewBox="0 0 22 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <path d="M9.5 1.86603C10.4282 1.33013 11.5718 1.33013 12.5 1.86603L19.0263 5.63397C19.9545 6.16987 20.5263 7.16025 20.5263 8.23205V15.7679C20.5263 16.8397 19.9545 17.8301 19.0263 18.366L12.5 22.134C11.5718 22.6699 10.4282 22.6699 9.5 22.134L2.97372 18.366C2.04552 17.8301 1.47372 16.8397 1.47372 15.7679V8.23205C1.47372 7.16025 2.04552 6.16987 2.97372 5.63397L9.5 1.86603Z" stroke="#B680FD" strokeWidth="2" strokeLinejoin="round" />
                        </svg>
                        <span className="h3id">{props.hexId}</span>

                    </div>
                    <div className="big-stats">
                        <div className="big-stat">
                            <div className="stat-head type-smallcap">Best RSSI</div>
                            <div className="stat-body">
                                {props.bestRssi}
                                <span className="stat-unit"> dBm</span>
                            </div>
                        </div>

                        <div className="big-stat">
                            <div className="stat-head type-smallcap">SNR</div>
                            <div className="stat-body">
                                {props.snr}
                                <span className="stat-unit"></span>
                            </div>
                        </div>

                        <div className="big-stat">
                            <div className="stat-head type-smallcap">Redundancy</div>
                            <div className="stat-body">
                                {props.uplinks && hotspotCount()}
                                <span className="stat-unit"> Hotspots</span>
                            </div>
                        </div>

                        <div className="big-stat">
                            <div className="stat-head type-smallcap">Hex Updated</div>
                            <div className="stat-body">
                                {props.uplinks && recentTime().number}
                                <span className="stat-unit"> {props.uplinks && recentTime().unit} Ago</span>
                            </div>
                        </div>

                    </div>
                    <div className="hotspots-table-container">
                        <table className="hotspots-table">
                            <thead className="hotspot-table-head type-smallcap">
                                <tr>
                                    <th className="table-left" title="Helium hotspot that heard the mapping device">Hotspots</th>
                                    <th className="table-right" title="Received Signal Strength Indicator - an estimated measure of power recieved">RSSI</th>
                                    <th className="table-right" title="Signal to noise ratio">SNR</th>
                                    <th className="table-right" title="Distance between hotspot and surveyed hex">Dist</th>
                                </tr>
                            </thead>
                            <tbody>
                                {props.uplinks && props.uplinks.map(uplink => (
                                    <tr key={uplink.id}>
                                        <td className="table-left animal-cell">{deKebab(uplink.hotspot_name)}</td>
                                        <td className="table-right util-liga-mono tighten table-numeric">{uplink.rssi}<span className="table-unit"> dBm</span></td>
                                        <td className="table-right util-liga-mono tighten table-numeric">{uplink.snr.toFixed(2)}</td>
                                        <td className="table-right util-liga-mono tighten table-numeric">{uplinkDistance(uplink.lat, uplink.lng).number}<span className="table-unit"> {uplinkDistance(uplink.lat, uplink.lng).unit}</span></td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                </div>
            }
        </div>
    );
}

export default InfoPane