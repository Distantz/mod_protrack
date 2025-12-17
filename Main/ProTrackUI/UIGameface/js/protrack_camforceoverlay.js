import * as DataStore from "/js/common/core/DataStore.js";
import * as Engine from "/js/common/core/Engine.js";
import * as Input from "/js/common/core/Input.js";
import * as Localisation from "/js/common/core/Localisation.js";
import * as Player from "/js/common/core/Player.js";
import * as System from "/js/common/core/System.js";
import * as preact from "/js/common/lib/preact.js";
import * as Format from "/js/common/util/LocalisationUtil.js";

import { loadDebugDefaultTools } from "/js/common/debug/DebugToolImports.js";
import { loadCSS } from "/js/common/util/CSSUtil.js";

import { Icon } from "/js/common/components/Icon.js";
import { Slider } from '/js/project/components/Slider.js';
import { Button } from '/js/project/components/Button.js';
import { ListStepperRow } from '/js/project/components/ListStepperRow.js';

import { Panel, PanelType } from '/js/project/components/panel/Panel.js';
import { Tab } from '/js/common/components/Tab.js';
import { MetricDisplay, DirectionalGForceMetric, KeyframeMetric } from '/js/protrack_metriccomponents.js';

import { DataStoreHelper } from '/js/common/util/DataStoreHelper.js';
import * as AccentColorUtil from '/js/project/utils/AccentColorUtil.js';
import * as FontConfig from "/js/config/FontConfig.js";
import * as UIScaleUtil from "/js/project/utils/UIScaleUtil.js";
FontConfig;
AccentColorUtil;
UIScaleUtil;

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
        visibleTabIndex: 0,
        trackMode: 0,
        posG: 1.0,
        latG: 0.0,
        time: 0.0
    };
    componentWillMount() {
        Engine.addListener("Show", this.onShow);
        Engine.addListener("Hide", this.onHide);

    }
    componentWillUnmount() {
        Engine.removeListener("Show", this.onShow);
        Engine.removeListener("Hide", this.onHide);
    }

    onChangeTab = (visibleIndex) => {
        this.setState({ visibleTabIndex: visibleIndex });
    }
    onTrackModeChange = (newTrackMode) => {
        this.setState({ trackMode: newTrackMode });
    }
    render(props, state) {
        if (!this.state.visible) {
            return preact.h("div", { className: "ProTrackUI_root" });
        }

        const items = [
            "[Loc_ProTrack_TM_Normal]",
            "[Loc_ProTrack_TM_ForceLock]",
            // "[Loc_ProTrack_TM_Gizmo]",
        ];

        var tabs = [
            // Tab one, force viz
            preact.h("div", { key: "tab1", className: "ProTrackUI_panelInner" },
                // Row 1

                false && preact.h("div", { className: "ProTrackUI_distributeRow" },
                    preact.h("div", { className: "ProTrackUI_flexRow" },
                        preact.h(Slider, {
                            // label: '[Loc_ProTrack_Scrub]',
                            min: 0,
                            max: 1,
                            step: 0.0001,
                            formatter: Format.float_3DP,
                            value: state.time,
                            onChange: this.onTimeChanged,
                            focusable: true
                        })
                    ),
                ),

                // Row 2 (control buttons)
                preact.h("div", { className: "ProTrackUI_distributeRow" },

                    // lefthand side
                    preact.h("div", { className: "ProTrackUI_minRow ProTrackUI_innerGap" },
                        preact.h(Button, {
                            icon: 'img/icons/locate.svg',
                            label: Format.stringLiteral('Anchor')
                        }),
                        preact.h(Button, {
                            icon: 'img/icons/redo.svg',
                            label: Format.stringLiteral('Resimulate')
                        }),
                        preact.h(Button, {
                            icon: 'img/icons/camera.svg',
                            label: Format.stringLiteral('Track Cam')
                        }),
                    ),

                    // Middle spacer
                    preact.h("div", { className: "ProTrackUI_flexRow" }),

                    false && preact.h("div", { className: "ProTrackUI_minRow ProTrackUI_innerGap" },
                        preact.h(Button, {
                            icon: 'img/icons/minus.svg',
                            // modifiers: 'negative'
                        }),
                        preact.h(Button, {
                            icon: 'img/icons/play.svg',
                            modifiers: 'positive'
                        }),
                        preact.h(Button, {
                            icon: 'img/icons/plus.svg',
                            // modifiers: 'positive'
                        }),
                    ),
                ),

                // Row 3
                preact.h("div", { className: "ProTrackUI_flexRow ProTrackUI_innerGap" },
                    preact.h(KeyframeMetric, {
                        icon: "img/icons/clock.svg",
                        formatter: (v) => v
                    }),
                    preact.h(DirectionalGForceMetric, {
                        dataKey: "vertGForce",
                        iconPrefix: "img/icons/protrack_vertg_",
                        threshold: 0.1,
                        directions: { positive: "d", negative: "u" },
                        formatter: Format.gForce_2DP
                    }),
                    preact.h(DirectionalGForceMetric, {
                        dataKey: "latGForce",
                        iconPrefix: "img/icons/protrack_latg_",
                        threshold: 0.25,
                        directions: { positive: "l", negative: "r" },
                        formatter: Format.gForce_2DP
                    }),
                    preact.h(MetricDisplay, {
                        dataKey: "speed",
                        icon: "img/icons/maxSpeed.svg",
                        formatter: Format.speedUnit_1DP
                    })
                )
            ),

            preact.h("div", { key: "tab2", className: "ProTrackUI_panelInner" },
                preact.h("div", { className: "ProTrackUI_flexRow" },
                    preact.h(ListStepperRow, { showInputIcon: true, modal: true, items: items, listIndex: state.trackMode, onChange: this.onTrackModeChange, label: "[Loc_ProTrack_TM_Label]" }),
                ),
                state.trackMode == 1 && preact.h("div", { className: "ProTrackUI_flexRow" },
                    preact.h(Slider, {
                        label: '[Loc_ProTrack_PosG]',
                        // rootClassName: "ProTrackUI_flex",
                        // modifiers: 'inner',
                        min: -6.0,
                        max: 6.0,
                        step: 0.05,
                        formatter: Format.gForce_2DP,
                        value: state.posG,
                        onChange: this.onPosGChanged,
                        focusable: true
                    }),
                    preact.h(Slider, {
                        label: '[Loc_ProTrack_LatG]',
                        // rootClassName: "ProTrackUI_flex",
                        // modifiers: 'inner',
                        min: -2.0,
                        max: 2.0,
                        step: 0.05,
                        formatter: Format.gForce_2DP,
                        value: state.latG,
                        onChange: this.onLatGChanged,
                        focusable: true
                    }),
                ),
            ),

            // Tab 2, settings
            preact.h("div", { key: "tab3", className: "ProTrackUI_panelInner" },
                preact.h("div", { className: "ProTrackUI_flexRow" },
                    preact.h(Slider, {
                        label: '[Loc_ProTrack_Heartline]',
                        // rootClassName: "ProTrackUI_flex",
                        // modifiers: 'inner',
                        min: -2.0,
                        max: 2.0,
                        step: 0.05,
                        formatter: Format.distanceUnit_2DP,
                        value: state.heartline,
                        onChange: this.onHeartlineChanged,
                        focusable: true
                    }),
                ),
            )
        ]

        return preact.h("div", { className: "ProTrackUI_root" },
            preact.h(Panel,
                {
                    rootClassName: "ProTrackUI_panel",
                    type: PanelType.default,
                    title: Format.stringLiteral('ProTrack'),
                    visibleTabIndex: state.visibleTabIndex,
                    onTabChange: this.onChangeTab,
                    modifiers: props.modifiers,
                    context: props.context,
                    onClose: props.onClose,
                    tabs: [
                        preact.h(Tab, { icon: '/img/icons/gforce.svg', label: Format.stringLiteral("Track Viz") }),
                        preact.h(Tab, { icon: '/img/icons/create.svg', label: Format.stringLiteral("Track Tools") }),
                        // preact.h(Tab, { icon: '/img/icons/placeholder.svg' }),
                        preact.h(Tab, { icon: '/img/icons/settings.svg', label: Format.stringLiteral("Settings") })
                    ],
                    children: tabs
                },
            )
        );

        // return preact.h("div", { className: "ProTrackUI_root" },
        //     preact.h("div", { className: "ProTrackUI_overlay" },
        //         // Row one, slider
        //         preact.h("div", { className: "ProTrackUI_row" },
        //             preact.h(Slider, {
        //                 // label: '[Loc_ProTrack_Scrub]',
        //                 rootClassName: 'ProTrackUI_stretch',
        //                 min: 0,
        //                 max: 1,
        //                 step: 0.0001,
        //                 formatter: Format.float_3DP,
        //                 value: state.time,
        //                 onChange: this.onTimeChanged,
        //                 focusable: true
        //             }),
        //         ),

        //         // Row two
        //         preact.h("div", { className: "ProTrackUI_row" },
        //             preact.h(CamForceKeyframes, null),
        //             preact.h(CamForceVert, null),
        //             preact.h(CamForceLat, null),
        //             preact.h(CamForceSpeed, null)
        //         ),

        //         preact.h("div", { className: "ProTrackUI_row" },
        //             preact.h(Slider, {
        //                 label: '[Loc_ProTrack_Heartline]',
        //                 modifiers: 'inner',
        //                 min: -2.0,
        //                 max: 2.0,
        //                 step: 0.05,
        //                 formatter: Format.distanceUnit_2DP,
        //                 value: state.heartline,
        //                 onChange: this.onHeartlineChanged,
        //                 focusable: true
        //             }),
        //             preact.h(Slider, {
        //                 label: '[Loc_ProTrack_PosG]',
        //                 modifiers: 'inner',
        //                 min: -2.0,
        //                 max: 6.0,
        //                 step: 0.05,
        //                 formatter: Format.gForce_2DP,
        //                 value: state.posG,
        //                 onChange: this.onPosGChanged,
        //                 focusable: true
        //             }),
        //             preact.h(Slider, {
        //                 label: '[Loc_ProTrack_LatG]',
        //                 modifiers: 'inner',
        //                 min: -2.0,
        //                 max: 2.0,
        //                 step: 0.05,
        //                 formatter: Format.gForce_2DP,
        //                 value: state.latG,
        //                 onChange: this.onLatGChanged,
        //                 focusable: true
        //             }),
        //         )
        //     ),
        // );
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

    onTimeChanged = (value) => {
        this.setState({ time: value });
        // Engine.sendEvent("ProtrackHeartlineChanged", value);
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
        return preact.h("div", { className: "ProTrackUI_minRow" },
            preact.h(Icon, { src: "img/icons/clock.svg", rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_metricText" }, `${state.currentKeyframe}/${state.keyframeCount}`)
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

        var icon = "img/icons/protrack_vertg_"
        const thres = 0.1

        if (state.verticalGForce > thres) {
            icon += "d.svg"
        }
        else if (-state.verticalGForce > thres) {
            icon += "u.svg"
        }
        else {
            icon += "n.svg"
        }

        const formattedValue = Localisation.translate(Format.gForce_2DP(state.verticalGForce));
        const displayValue = state.lateralGForce >= 0 ? `\u00A0${formattedValue}` : formattedValue;

        return preact.h("div", { className: "ProTrackUI_minRow" },
            preact.h(Icon, { src: icon, rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_metricText" }, displayValue)
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

        var icon = "img/icons/protrack_latg_"
        const thres = 0.25

        if (state.lateralGForce > thres) {
            icon += "l.svg"
        }
        else if (-state.lateralGForce > thres) {
            icon += "r.svg"
        }
        else {
            icon += "n.svg"
        }

        const formattedValue = Localisation.translate(Format.gForce_2DP(state.lateralGForce));
        const displayValue = state.lateralGForce >= 0 ? `\u00A0${formattedValue}` : formattedValue;

        return preact.h("div", { className: "ProTrackUI_minRow" },
            preact.h(Icon, { src: icon, rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_metricText" }, displayValue)
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
        return preact.h("div", { className: "ProTrackUI_minRow" },
            preact.h(Icon, { src: "img/icons/maxSpeed.svg", rootClassName: "ProTrackUI_icon" }),
            preact.h("div", { className: "ProTrackUI_metricText" }, Localisation.translate(Format.speedUnit_1DP(state.speed)))
        );
    }
}