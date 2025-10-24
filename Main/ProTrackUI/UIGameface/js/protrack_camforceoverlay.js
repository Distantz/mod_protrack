import * as Engine from '/js/common/core/Engine.js';
import * as Localisation from '/js/common/core/Localisation.js';
import * as preact from '/js/common/lib/preact.js';
import { loadCSS } from '/js/common/util/CSSUtil.js';
import * as FontConfig from '/js/config/FontConfig.js';

FontConfig;
Engine.intialiseSystems([
	{system: Engine.Systems.System, initaliser: System.attachToEngineReadyForSystem }
]);

Engine.whenReady.then(async() => {
    await loadCSS('project/Shared');
    await loadDebugDefaultTools();
    
    preact.render(preact.h(CamForceOverlay, null), document.body);
    Engine.sendEvent("OnReady");
}).catch(Engine.defaultCatch);

class CamForceOverlay extends preact.Component {
    static defaultProps = {
        moduleName = "ProTrackUI"
    };
    state = {
        visible: false
    };
    componentWillMount() {
	Engine.addListener("Show", this.onShow);
	Engine.addListener("Hide", this.onHide);
    }
    componentWillUnmount() {
	Engine.removeListener("Show", this.onShow);
	Engine.removeListener("Hide", this.onHide);
    }
    
    render(props, state) {
	if(!this.state.visible)
	{
	    return preact.h("div", {className:"ProTrackUI_root"});
	}
	return (
	    preact.h("div", {className:"ProTrackUI_root"},
		preact.h("div", {className:"ProTrackUI_overlay"},
		    preact.h("div")
		)
	    )
	)
    }
}
