import * as preact from "/js/common/lib/preact.js";
import * as Format from "/js/common/util/LocalisationUtil.js";
import { DirectionalGForceMetric, KeyframeMetric, MetricDisplay } from '/js/protrack_metriccomponents.js';

export const StateMetrics = ({ trainData, follower, layout = "row" }) => {
    const containerClass = layout === "column"
        ? "ProTrackUI_innerGap ProTrackUI_flexColumn"
        : "ProTrackUI_innerGap ProTrackUI_flexRow";

    return preact.h("div", { className: containerClass },
        (trainData != null && trainData.currentKeyframe != null && trainData.maxKeyframe != null) && preact.h(KeyframeMetric, {
            icon: "img/icons/clock.svg",
            formatter: (v) => v,
            currentKeyframe: trainData.currentKeyframe,
            maxKeyframe: trainData.maxKeyframe,
        }),
        (follower != null && follower.vertG != null) && preact.h(DirectionalGForceMetric, {
            dataKey: "vertGForce",
            iconPrefix: "img/icons/protrack_vertg_",
            threshold: 0.1,
            directions: { positive: "d", negative: "u" },
            formatter: Format.gForce_2DP,
            value: follower.vertG,
        }),
        (follower != null && follower.latG != null) && preact.h(DirectionalGForceMetric, {
            dataKey: "latGForce",
            iconPrefix: "img/icons/protrack_latg_",
            threshold: 0.25,
            directions: { positive: "l", negative: "r" },
            formatter: Format.gForce_2DP,
            value: follower.latG,
        }),
        (trainData != null && trainData.speed != null) && preact.h(MetricDisplay, {
            dataKey: "speed",
            icon: "img/icons/maxSpeed.svg",
            formatter: Format.speedUnit_1DP,
            value: trainData.speed
        })
    );
};