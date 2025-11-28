import * as DataStore from "/js/common/core/DataStore.js";
import * as Engine from "/js/common/core/Engine.js";
import * as Input from "/js/common/core/Input.js";
import * as Localisation from "/js/common/core/Localisation.js";
import * as Player from "/js/common/core/Player.js";
import * as System from "/js/common/core/System.js";
import { loadDebugDefaultTools } from "/js/common/debug/DebugToolImports.js";
import * as preact from "/js/common/lib/preact.js";
import * as Focus from "/js/common/core/Focus.js";
import { loadCSS } from "/js/common/util/CSSUtil.js";
import * as Format from "/js/common/util/LocalisationUtil.js";
import * as FontConfig from "/js/config/FontConfig.js";
import { Icon } from "/js/common/components/Icon.js";
import { DataStoreHelper } from '/js/common/util/DataStoreHelper.js';
import { SliderRow } from '/js/project/components/SliderRow.js';
FontConfig;

Engine.initialiseSystems([
    {
        system: Engine.Systems.System,
        initialiser: System.attachToEngineReadyForSystem,
    },
    {
        system: Engine.Systems.DataStore,
        initialiser: DataStore.attachToEngineReadyForSystem,
    },
    {
        system: Engine.Systems.Input,
        initialiser: Input.attachToEngineReadyForSystem,
    },
    {
        system: Engine.Systems.Localisation,
        initialiser: Localisation.attachToEngineReadyForSystem,
    },
    {
        system: Engine.Systems.Player,
        initialiser: Player.attachToEngineReadyForSystem,
    },
]);


let datapoint = {
    currentKeyframe: 959,
    keyframeCount: 1000,
    g: {}
}

Engine.whenReady.then(async () => {
    await loadCSS('project/Shared');
    await loadDebugDefaultTools();

    //datapoint.currentKeyframe = DataStore.getValue(["ProTrack"],"currKeyframe");
    //datapoint.keyframeCount = DataStore.getValue(["ProTrack"],"keyframeCount");

    preact.render(preact.h(CamForceOverlay, null), document.body);
    Engine.sendEvent("OnReady");
}).catch(Engine.defaultCatch);

class CamForceOverlay extends preact.Component {
    static defaultProps = {
        moduleName: "ProTrackUI"
    };
    state = {
        visible: false,
        heartline: 0.0,
        posG: 1.0,
        latG: 0.0
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
        if (!this.state.visible) {
            return preact.h("div", { className: "ProTrackUI_root" });
        }

        return preact.h("div", { className: "ProTrackUI_root" },
            preact.h("div", { className: "ProTrackUI_overlay" },
                preact.h(CamForceKeyframes, null),
                preact.h(CamForceVert, null),
                preact.h(CamForceLat, null),
                preact.h(CamForceSpeed, null),
                preact.h(SliderRow, {
                    label: '[Loc_ProTrack_Heartline]',
                    modifiers: 'inner',
                    min: -2.0,
                    max: 2.0,
                    step: 0.05,
                    formatter: Format.float_2DP,
                    value: state.heartline,
                    onChange: this.onHeartlineChanged,
                    focusable: true
                }),
                preact.h(SliderRow, {
                    label: '[Loc_ProTrack_PosG]',
                    modifiers: 'inner',
                    min: -2.0,
                    max: 6.0,
                    step: 0.05,
                    formatter: Format.float_2DP,
                    value: state.posG,
                    onChange: this.onPosGChanged,
                    focusable: true
                }),
                preact.h(SliderRow, {
                    label: '[Loc_ProTrack_LatG]',
                    modifiers: 'inner',
                    min: -2.0,
                    max: 2.0,
                    step: 0.05,
                    formatter: Format.float_2DP,
                    value: state.latG,
                    onChange: this.onLatGChanged,
                    focusable: true
                }),
                // preact.h("div", ),
                //preact.h("div", ),
                //preact.h("div", )
            )
        );
    }

    onLatGChanged = (value) => {
        this.setState({ latG: value });
        Engine.sendEvent("ProtrackLatGChanged", value);
    };

    onPosGChanged = (value) => {
        this.setState({ posG: value });
        Engine.sendEvent("ProtrackPosGChanged", value);
    };

    onHeartlineChanged = (value) => {
        this.setState({ heartline: value });
        Engine.sendEvent("ProtrackHeartlineChanged", value);
    };

    onShow = () => {
        this.setState({ visible: true });
    }
    onHide = () => {
        this.setState({ visible: false });
    }
}

class CamForceKeyframes extends preact.Component {
    state = {
        currentKeyframe: 959,
        keyframeCount: 1000
    }
    _helper;
    componentWillUnmount() {
        this._helper.clear();
        this._helper = undefined;
    }
    componentWillMount() {
        this._helper = new DataStoreHelper();
        this._helper.addPropertyListener(["ProTrack"], "currKeyframe", (value) => {
            this.setState({ currentKeyframe: value });
        });
        this._helper.addPropertyListener(["ProTrack"], "keyframeCount", (value) => {
            this.setState({ keyframeCount: value });
        });
        this._helper.getAllPropertiesNow();

    }
    render(props, state) {
        return preact.h("div", { className: "ProTrackUI_row" },
            preact.h(Icon, { src: "img/icons/clock.svg", rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_text" }, `${state.currentKeyframe}/${state.keyframeCount}`)
        );
    }
}

class CamForceVert extends preact.Component {
    state = {
        verticalGForce: 0.00
    }
    _helper;
    componentWillUnmount() {
        this._helper.clear();
        this._helper = undefined;
    }
    componentWillMount() {
        this._helper = new DataStoreHelper();
        this._helper.addPropertyListener(["ProTrack"], "vertGForce", (value) => {
            this.setState({ verticalGForce: value });
        });
        this._helper.getAllPropertiesNow();

    }
    render(props, state) {
        return preact.h("div", { className: "ProTrackUI_row" },
            preact.h(Icon, { src: "img/icons/widgetVertical.svg", rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_text" }, Localisation.translate(Format.gForce_2DP(state.verticalGForce)))
        );
    }
}

class CamForceLat extends preact.Component {
    state = {
        lateralGForce: 0.00
    }
    _helper;
    componentWillUnmount() {
        this._helper.clear();
        this._helper = undefined;
    }
    componentWillMount() {
        this._helper = new DataStoreHelper();
        this._helper.addPropertyListener(["ProTrack"], "latGForce", (value) => {
            this.setState({ lateralGForce: value });
        });
        this._helper.getAllPropertiesNow();

    }
    render(props, state) {
        return preact.h("div", { className: "ProTrackUI_row" },
            preact.h(Icon, { src: "img/icons/widgetHorizontal.svg", rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_text" }, Localisation.translate(Format.gForce_2DP(state.lateralGForce)))
        );
    }
}

class CamForceSpeed extends preact.Component {
    state = {
        speed: 0.00
    }
    _helper;
    componentWillUnmount() {
        this._helper.clear();
        this._helper = undefined;
    }
    componentWillMount() {
        this._helper = new DataStoreHelper();
        this._helper.addPropertyListener(["ProTrack"], "speed", (value) => {
            this.setState({ speed: value });
        });
        this._helper.getAllPropertiesNow();

    }
    render(props, state) {
        return preact.h("div", { className: "ProTrackUI_row" },
            preact.h(Icon, { src: "img/icons/maxSpeed.svg", rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_text" }, Localisation.translate(Format.speedUnit_1DP(state.speed)))
        );
    }
}


