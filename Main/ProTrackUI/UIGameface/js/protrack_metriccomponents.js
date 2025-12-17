import * as preact from "/js/common/lib/preact.js";
import * as Localisation from "/js/common/core/Localisation.js";
import * as Format from "/js/common/util/LocalisationUtil.js";
import { Icon } from "/js/common/components/Icon.js";
import { DataRow } from '/js/project/components/DataRow.js';
import { DataStoreHelper } from '/js/common/util/DataStoreHelper.js';

export class MetricDisplay extends preact.Component {
    state = {
        value: 0.00
    }
    _helper;

    componentWillUnmount() {
        this._helper.clear();
        this._helper = undefined;
    }

    componentWillMount() {
        this._helper = new DataStoreHelper();
        this._helper.addPropertyListener(["ProTrack"], this.props.dataKey, (value) => {
            this.setState({ value: value });
        });
        this._helper.getAllPropertiesNow();
    }

    getIcon() {
        return this.props.icon;
    }

    formatValue() {
        const { formatter } = this.props;
        const { value } = this.state;
        const formatted = Localisation.translate(formatter(value));
        return formatted;
    }

    render() {

        // return preact.h(DataRow, {
        //     rootClassName: "ProTrackUI_metricDataRow",
        //     icon: this.getIcon(),
        //     value: Format.stringLiteral(this.formatValue()),
        // });
        return preact.h("div", { className: 'DataRow_root ProTrackUI_metricDataRow' },
            preact.h(Icon, { modifiers: 'DataRow_icon', src: this.getIcon() }),
            preact.h("div", { className: 'DataRow_value' },
                this.formatValue()
            )
        );

        // return preact.h("div", { className: "ProTrackUI_metric" },
        //     preact.h(Icon, { src: this.getIcon() }),
        //     preact.h("div", { className: "ProTrackUI_metricValue" }, this.formatValue())
        // );
    }
}

export class DirectionalGForceMetric extends MetricDisplay {
    getIcon() {
        const { iconPrefix, threshold, directions } = this.props;
        const { value } = this.state;

        if (value > threshold) {
            return `${iconPrefix}${directions.positive}.svg`;
        } else if (-value > threshold) {
            return `${iconPrefix}${directions.negative}.svg`;
        } else {
            return `${iconPrefix}n.svg`;
        }
    }

    formatValue() {
        const { formatter } = this.props;
        const { value } = this.state;
        return Localisation.translate(formatter(value));
    }
}

export class KeyframeMetric extends MetricDisplay {
    state = {
        currentKeyframe: 0,
        keyframeCount: 1000
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

    formatValue() {
        const { currentKeyframe, keyframeCount } = this.state;
        return `${currentKeyframe ?? 0}/${keyframeCount ?? 0}`;
    }
}