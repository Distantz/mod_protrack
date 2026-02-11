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
import { CheckBox } from '/js/project/components/CheckBox.js';

import { Panel, PanelType } from '/js/project/components/panel/Panel.js';
import { Tab } from '/js/common/components/Tab.js';
import { StateMetrics } from '/js/protrack_datadisplaycomponents.js';
import { Messagetype, WarningMessage } from '/js/project/components/WarningMessage.js';
import { DataStoreContextWrapper } from '/js/project/data/DataStoreContextWrapper.js';

import * as AccentColorUtil from '/js/project/utils/AccentColorUtil.js';
import * as FontConfig from "/js/config/FontConfig.js";
import * as UIScaleUtil from "/js/project/utils/UIScaleUtil.js";
FontConfig;
AccentColorUtil;
UIScaleUtil;

function print(value) {
    Engine.sendEvent("Protrack_Log", value);
}

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

const DEBUG = true;

Engine.whenReady.then(async () => {
    await loadCSS('project/Shared');
    loadCSS('project/components/panel/Panel');
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
        visibleTabIndex: 0,
    };
    _mainDataContext = undefined;
    _trainDataContext = undefined;
    componentWillMount() {
        Engine.addListener("Show", this.onShow);
        Engine.addListener("Hide", this.onHide);

        this._mainDataContext = new DataStoreContextWrapper(
            ['ProTrack'],
            [],
            [
                'cameraIsHeartlineMode',
                'inCamera',
                'trackMode',
                'heartline',
                'playingInDir',
                'time',
            ],
            []
        );

        this._trainDataContext = new DataStoreContextWrapper(
            ['ProTrack', 'trainData'],
            [],
            ['speed', 'currentKeyframe', 'maxKeyframe'],
            [{
                context: ['followers'],
                fixedFields: [],
                dynamicFields: ['screenX', 'screenY', 'vertG', 'latG'],
                sortField: '',
                LUTFields: []
            }]
        );

        this._mainDataContext.onChange.add((e) => {
            this.forceUpdate();
        });

        this._trainDataContext.onChange.add((e) => {
            this.forceUpdate();
        });

        this._trainDataContext.onChildrenChange.add((e) => {
            this.forceUpdate();
        });
    }

    componentWillUnmount() {
        Engine.removeListener("Show", this.onShow);
        Engine.removeListener("Hide", this.onHide);

        this._mainDataContext.dispose();
        this._mainDataContext = undefined;
        this._trainDataContext.dispose();
        this._trainDataContext = undefined;
    }

    render(props, state) {
        if (!this.state.visible) {
            return preact.h("div", { className: "ProTrackUI_root" });
        }

        var data = this._mainDataContext?.data || {};
        var trainData = this._trainDataContext?.data || {};
        var followersWrapper = (this._trainDataContext?.getChildren(["followers"])) || null;

        var followers = followersWrapper.source.map(item => item.wrapper.data);
        if (followers.length == 0 && DEBUG) {
            followers = [
                {
                    screenX: 0.5,
                    screenY: 0.5,
                    vertG: 1.5,
                    latG: 0.5
                }
            ];
        }

        const hasData = followers.length > 0;

        const trackModeOptions = [
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
                            value: data.time,
                            onChange: this.onTimeChanged,
                            focusable: true,
                            disabled: !hasData
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
                            disabled: !hasData
                        }),
                        preact.h(Button, {
                            icon: 'img/icons/camera.svg',
                            label: Format.stringLiteral(data.inCamera ? 'Exit Track Cam' : "Enter Track Cam"),
                            onSelect: this.onChangeCam,
                            disabled: !hasData
                        }),
                    ),

                    // Middle spacer
                    preact.h("div", { className: "ProTrackUI_flexRow" }),

                    preact.h("div", { className: "ProTrackUI_minRow ProTrackUI_innerGap" },
                        data.playingInDir != -1 && preact.h(Button, {
                            icon: 'img/icons/arrow_left.svg',
                            onSelect: this.onScrubBackwards,
                            disabled: !hasData
                        }),

                        data.playingInDir != 0 && preact.h(Button, {
                            icon: 'img/icons/pause.svg',
                            onSelect: this.onScrubPause,
                            modifiers: 'negative',
                            disabled: !hasData
                        }),

                        data.playingInDir != 1 && preact.h(Button, {
                            icon: 'img/icons/arrow_right.svg',
                            onSelect: this.onScrubForwards,
                            disabled: !hasData
                        }),
                    ),
                ),

                // Row 3
                hasData && preact.h("div", { className: "ProTrackUI_flexRow ProTrackUI_innerGap" },
                    StateMetrics({
                        trainData: trainData,
                        follower: followers[0]
                    }),
                )
            ),

            // Tab 2, track tools
            preact.h("div", { key: "tab2", className: "ProTrackUI_panelInner" },
                preact.h("div", { className: "ProTrackUI_flexRow" },
                    preact.h(ListStepperRow, { showInputIcon: true, modal: true, items: trackModeOptions, listIndex: data.trackMode, onChange: this.onTrackModeChange, label: "[Loc_ProTrack_TM_Label]" }),
                ),
                // Warning message
                data.trackMode == 1 && !hasData && preact.h("div", { className: "ProTrackUI_flexRow" },
                    preact.h(WarningMessage, { label: Format.stringLiteral('TrackViz data needed at track end for ForceLock.'), type: Messagetype.Neutral, show: true })
                ),
                data.trackMode == 1 && hasData && preact.h("div", { className: "ProTrackUI_flexRow" },
                    preact.h(Slider, {
                        label: '[Loc_ProTrack_VertG]',
                        // rootClassName: "ProTrackUI_flex",
                        // modifiers: 'inner',
                        min: -6.0,
                        max: 6.0,
                        step: 0.05,
                        formatter: Format.gForce_2DP,
                        value: data.forceLockVertG,
                        onChange: this.onVertGChanged,
                        focusable: true,
                        disabled: !hasData,
                    }),
                    preact.h(Slider, {
                        label: '[Loc_ProTrack_LatG]',
                        // rootClassName: "ProTrackUI_flex",
                        // modifiers: 'inner',
                        min: -2.0,
                        max: 2.0,
                        step: 0.05,
                        formatter: Format.gForce_2DP,
                        value: data.forceLockLatG,
                        onChange: this.onLatGChanged,
                        focusable: true,
                        disabled: !hasData,
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
                        value: data.heartline,
                        onChange: this.onHeartlineChanged,
                        focusable: true
                    }),
                ),

                preact.h("div", { className: "ProTrackUI_flexRow" },
                    preact.h(CheckBox, {
                        label: Format.stringLiteral('Use Heartline Camera'),
                        toggled: data.cameraIsHeartlineMode,
                        onToggle: this.onHeartlineCameraChanged,
                        modifiers: "stretch",
                    })
                ),
            )
        ]

        return preact.h("div", { className: "ProTrackUI_root" },

            ...(
                hasData ?
                    // Good case (has some data)
                    followers.map((follower, idx) =>
                        preact.h("div", {
                            style: {
                                position: "absolute",
                                left: `${follower.screenX * 100}%`,
                                top: `${follower.screenY * 100}%`,
                            }
                        },
                            preact.h("div", {
                                className: "Panel_panel Panel_content",
                                style: {
                                    "min-width": "15rem"
                                }
                            },
                                StateMetrics({
                                    follower: follower,
                                    layout: "column"
                                })
                            )
                        )
                    )
                    :
                    // Bad case, unpack empty
                    []
            ),

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
                        preact.h(Tab, { icon: '/img/icons/gforce.svg', label: Format.stringLiteral("TrackViz") }),
                        preact.h(Tab, { icon: '/img/icons/create.svg', label: Format.stringLiteral("Track Tools") }),
                        // preact.h(Tab, { icon: '/img/icons/placeholder.svg' }),
                        preact.h(Tab, { icon: '/img/icons/settings.svg', label: Format.stringLiteral("Settings") })
                    ],
                    children: tabs
                },
            )
        );
    }

    // Ui listeners

    onChangeTab = (visibleIndex) => {
        this.setState({ visibleTabIndex: visibleIndex });
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

    onTrackModeChange = (newTrackMode) => {
        Engine.sendEvent("Protrack_TrackModeChanged", newTrackMode);
    }

    onHeartlineCameraChanged = (heartlineCamRequested) => {
        Engine.sendEvent("Protrack_HeartlineCamChanged", heartlineCamRequested);
    }

    onTimeChanged = (value) => {
        // Pause if playing (bad for UX)
        if (this._mainDataContext.data.playingInDir != 0) {
            this.onScrubPause();
        }
        Engine.sendEvent("Protrack_TimeChanged", value);
    };

    onLatGChanged = (value) => {
        Engine.sendEvent("Protrack_LatGChanged", value);
    };

    onVertGChanged = (value) => {
        Engine.sendEvent("Protrack_VertGChanged", value);
    };

    onHeartlineChanged = (value) => {
        Engine.sendEvent("Protrack_HeartlineChanged", value);
    };

    // Engine visibility listeners

    onShow = () => {
        this.setState({ visible: true });
    }
    onHide = () => {
        this.setState({ visible: false });
    }
}