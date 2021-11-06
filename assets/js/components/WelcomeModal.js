import React from 'react'

function WelcomeModal(props) {
    const [showWelcomeModal, setshowWelcomeModal] = React.useState(true);
    const onCloseWelcomeModalClick = () => showWelcomeModal(false);
    
    return (
        <div>
            { props.showWelcomeModal &&
                <div className="modal">
                    <div className="illo-header">
                        <h1 className="modal-title">Shape the future of Mappers</h1>
                    </div>
                    <button aria-label="Close intro window" className="close-button modal-close" type="button" onClick={props.onCloseWelcomeModalClick}>
                        <svg className="icon" width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
                            <path d="M7.9998 6.54957L13.4284 1.12096C13.8289 0.720422 14.4783 0.720422 14.8789 1.12096C15.2794 1.5215 15.2794 2.1709 14.8789 2.57144L9.45028 8.00004L14.8789 13.4287C15.2794 13.8292 15.2794 14.4786 14.8789 14.8791C14.4783 15.2797 13.8289 15.2797 13.4284 14.8791L7.9998 9.45052L2.57119 14.8791C2.17065 15.2797 1.52125 15.2797 1.12072 14.8791C0.720178 14.4786 0.720178 13.8292 1.12072 13.4287L6.54932 8.00004L1.12072 2.57144C0.720178 2.1709 0.720178 1.5215 1.12072 1.12096C1.52125 0.720422 2.17065 0.720422 2.57119 1.12096L7.9998 6.54957Z"/>
                        </svg>
                    </button>
                    
                    <p className="modal-copy">We're getting the conversation started with this release. Your feedback is key in defining the features in the next evolution of this tool.</p>
                    <p className="modal-copy">Visit <a href="https://docs.helium.com/use-the-network/coverage-mapping" target="_blank">Docs</a> to find a few ways to give input or jump into <a href="https://github.com/helium/mappers" target="_blank">GitHub</a> to file an issue or contribute.</p>
                </div>
            }
        </div>
    )
}

export default WelcomeModal