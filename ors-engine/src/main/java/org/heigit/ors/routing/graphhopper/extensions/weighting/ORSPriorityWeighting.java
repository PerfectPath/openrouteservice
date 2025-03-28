/*  This file is part of Openrouteservice.
 *
 *  Openrouteservice is free software; you can redistribute it and/or modify it under the terms of the
 *  GNU Lesser General Public License as published by the Free Software Foundation; either version 2.1
 *  of the License, or (at your option) any later version.

 *  This library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *  See the GNU Lesser General Public License for more details.

 *  You should have received a copy of the GNU Lesser General Public License along with this library;
 *  if not, see <https://www.gnu.org/licenses/>.
 */
package org.heigit.ors.routing.graphhopper.extensions.weighting;

import com.graphhopper.routing.ev.DecimalEncodedValue;
import com.graphhopper.routing.util.FlagEncoder;
import com.graphhopper.routing.weighting.AbstractWeighting;
import com.graphhopper.routing.weighting.TurnCostProvider;
import com.graphhopper.routing.weighting.Weighting;
import com.graphhopper.util.EdgeIteratorState;
import com.graphhopper.util.PMap;
import org.heigit.ors.routing.graphhopper.extensions.flagencoders.FlagEncoderKeys;
import org.heigit.ors.routing.graphhopper.extensions.util.PriorityCode;

import static com.graphhopper.routing.util.EncodingManager.getKey;

public class ORSPriorityWeighting extends AbstractWeighting {
    private static final double PRIORITY_BEST = PriorityCode.BEST.getValue();
    private static final double PRIORITY_UNCHANGED = PriorityCode.UNCHANGED.getValue();
    private final DecimalEncodedValue priorityEncoder;
    private final Weighting superWeighting;

    public ORSPriorityWeighting(FlagEncoder encoder, TurnCostProvider tcp, Weighting superWeighting) {
        super(encoder, tcp);
        this.superWeighting = superWeighting;
        priorityEncoder = encoder.getDecimalEncodedValue(getKey(encoder, FlagEncoderKeys.PRIORITY_KEY));
    }

    @Override
    public double calcEdgeWeight(EdgeIteratorState edgeState, boolean reverse, long edgeEnterTime) {
        double weight = superWeighting.calcEdgeWeight(edgeState, reverse, edgeEnterTime);
        if (Double.isInfinite(weight))
            return Double.POSITIVE_INFINITY;

        double priority = priorityEncoder.getDecimal(reverse, edgeState.getFlags());

        double normalizedPriority = priority * PRIORITY_BEST - PRIORITY_UNCHANGED;

        double factor = Math.pow(2, normalizedPriority / (PRIORITY_UNCHANGED - PRIORITY_BEST));

        return weight * factor;
    }

    @Override
    public double getMinWeight(double distance) {
        return 0;
    }

    @Override
    public double calcEdgeWeight(EdgeIteratorState edgeState, boolean reverse) {
        return calcEdgeWeight(edgeState, reverse, -1);
    }

    @Override
    public boolean equals(Object obj) {
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        final ORSPriorityWeighting other = (ORSPriorityWeighting) obj;
        return toString().equals(other.toString());
    }

    @Override
    public int hashCode() {
        return ("ORSPriorityWeighting" + this).hashCode();
    }

    @Override
    public String getName() {
        return "recommended";
    }
}
