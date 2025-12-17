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
        // Ui data
        visible: false,
        visibleTabIndex: 0,

        // Editor data
        hasData: false,
        inCamera: false,
        trackMode: 0,
        heartline: 0.0,

        // Playhead data
        time: 0.0,
        playingInDir: 0,
        posG: 1.0,
        latG: 0.0,
        time: 0.0
    };
    _helper = undefined;
    componentWillMount() {
        Engine.addListener("Show", this.onShow);
        Engine.addListener("Hide", this.onHide);
        Engine.addListener("Protrack_ResetTrackMode", this.onResetTrackMode);

        // Bind to datastore
        this._helper = new DataStoreHelper();

        this._helper.addPropertyListener(["ProTrack"], "inCamera", (value) => {
            this.setState({ inCamera: value });
        });

        this._helper.addPropertyListener(["ProTrack"], "playingInDir", (value) => {
            this.setState({ playingInDir: value });
        });

        this._helper.addPropertyListener(["ProTrack"], "time", (value) => {
            this.setState({ time: value });
        });

        this._helper.addPropertyListener(["ProTrack"], "hasData", (value) => {
            this.setState({ hasData: value });
        });

        this._helper.getAllPropertiesNow();
    }
    componentWillUnmount() {
        Engine.removeListener("Show", this.onShow);
        Engine.removeListener("Hide", this.onHide);
        Engine.removeListener("Protrack_ResetTrackMode", this.onResetTrackMode);
        this._helper.clear();
        this._helper = undefined;
    }

    render(props, state) {
        if (!this.state.visible) {
            return preact.h("div", { className: "ProTrackUI_root" });
        }

        const items = [
            "[Loc_ProTrack_TM_Normal]",
            "[Loc_ProTrack_TM_ForceLock]",
            "[Loc_ProTrack_TM_Gizmo]",
        ];

        var tabs = [
            // Tab one, force viz
            preact.h("div", { key: "tab1", className: "ProTrackUI_panelInner" },

                // Row 1
                preact.h("div", { className: "ProTrackUI_distributeRow" },
                    preact.h("div", { className: "ProTrackUI_flexRow" },
                        preact.h(Slider, {
                            // label: '[Loc_ProTrack_Scrub]',
                            min: 0,
                            max: 1,
                            step: 0.0001,
                            formatter: Format.float_3DP,
                            value: state.time,
                            onChange: this.onTimeChanged,
                            focusable: true,
                            disabled: !state.hasData
                        })
                    ),
                ),

                // Row 2 (control buttons)
                preact.h("div", { className: "ProTrackUI_distributeRow" },

                    // lefthand side
                    preact.h("div", { className: "ProTrackUI_minRow ProTrackUI_innerGap" },
                        preact.h(Button, {
                            icon: 'img/icons/locate.svg',
                            label: Format.stringLiteral('Anchor'),
                            onSelect: this.onReanchor,
                        }),
                        preact.h(Button, {
                            icon: 'img/icons/redo.svg',
                            label: Format.stringLiteral('Resimulate'),
                            onSelect: this.onResimulate,
                            disabled: !state.hasData
                        }),
                        preact.h(Button, {
                            icon: 'img/icons/camera.svg',
                            label: Format.stringLiteral(state.inCamera ? 'Exit Track Cam' : "Enter Track Cam"),
                            onSelect: this.onChangeCam,
                            disabled: !state.hasData
                        }),
                    ),

                    // Middle spacer
                    preact.h("div", { className: "ProTrackUI_flexRow" }),

                    preact.h("div", { className: "ProTrackUI_minRow ProTrackUI_innerGap" },
                        state.playingInDir != -1 && preact.h(Button, {
                            icon: 'img/icons/arrow_left.svg',
                            onSelect: this.onScrubBackwards,
                            disabled: !state.hasData
                        }),

                        state.playingInDir != 0 && preact.h(Button, {
                            icon: 'img/icons/pause.svg',
                            onSelect: this.onScrubPause,
                            modifiers: 'negative',
                            disabled: !state.hasData
                        }),

                        state.playingInDir != 1 && preact.h(Button, {
                            icon: 'img/icons/arrow_right.svg',
                            onSelect: this.onScrubForwards,
                            disabled: !state.hasData
                        }),
                    ),
                ),

                // Row 3
                state.hasData && preact.h("div", { className: "ProTrackUI_flexRow ProTrackUI_innerGap" },
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

            // Tab 2, track tools
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

            // Tab 3, settings
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
    }

    // Engine event listeners

    onResetTrackMode = () => {
        this.onTrackModeChange(0)
    }

    // Button responders

    onReanchor = () => {
        Engine.sendEvent("Protrack_ReanchorRequested");
    }

    onResimulate = () => {
        Engine.sendEvent("Protrack_ResimulateRequested");
    }

    onChangeCam = () => {
        Engine.sendEvent("Protrack_ChangeCamModeRequested");
    }

    onScrubBackwards = () => {
        Engine.sendEvent("Protrack_PlayChanged", -1);
    }

    onScrubForwards = () => {
        Engine.sendEvent("Protrack_PlayChanged", 1);
    }

    onScrubPause = () => {
        Engine.sendEvent("Protrack_PlayChanged", 0);
    }

    // Value listeners

    onChangeTab = (visibleIndex) => {
        this.setState({ visibleTabIndex: visibleIndex });
    }

    onTrackModeChange = (newTrackMode) => {
        this.setState({ trackMode: newTrackMode });
        Engine.sendEvent("ProtrackTrackModeChanged", newTrackMode);
    }

    onTimeChanged = (value) => {

        // Pause if playing (bad for UX)
        if (this.state.playingInDir != 0) {
            this.onScrubPause();
        }

        this.setState({ time: value });
        Engine.sendEvent("Protrack_TimeChanged", value);
    };

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

    // Engine visibility listeners

    onShow = () => {
        this.setState({ visible: true });
    }
    onHide = () => {
        this.setState({ visible: false });
    }
}