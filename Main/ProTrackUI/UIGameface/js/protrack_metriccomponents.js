import * as preact from "/js/common/lib/preact.js";
import * as Localisation from "/js/common/core/Localisation.js";
import { Icon } from "/js/common/components/Icon.js";

export class MetricDisplay extends preact.Component {
    getIcon() {
        return this.props.icon;
    }

    formatValue() {
        const { formatter, value = 0 } = this.props;
        const formatted = Localisation.translate(formatter(value));
        return formatted;
    }

    render() {
        return preact.h("div", { className: 'DataRow_root ProTrackUI_metricDataRow' },
            preact.h(Icon, { modifiers: 'DataRow_icon', src: this.getIcon() }),
            preact.h("div", { className: 'DataRow_value' },
                this.formatValue()
            )
        );
    }
}

export class DirectionalGForceMetric extends MetricDisplay {
    getIcon() {
        const { iconPrefix, threshold, directions, value = 0 } = this.props;

        if (value > threshold) {
            return `${iconPrefix}${directions.positive}.svg`;
        } else if (-value > threshold) {
            return `${iconPrefix}${directions.negative}.svg`;
        } else {
            return `${iconPrefix}n.svg`;
        }
    }

    formatValue() {
        const { formatter, value = 0 } = this.props;
        return Localisation.translate(formatter(value));
    }
}

export class KeyframeMetric extends MetricDisplay {
    formatValue() {
        const { currentKeyframe = 0, maxKeyframe = 0 } = this.props;
        return `${currentKeyframe}/${maxKeyframe}`;
    }
}