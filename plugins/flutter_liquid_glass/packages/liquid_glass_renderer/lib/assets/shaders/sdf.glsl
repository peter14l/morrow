// Shape array uniforms - 6 floats per shape (type, centerX, centerY, sizeW, sizeH, cornerRadius)
// Reduced from 64 to 16 shapes to fit Impeller's uniform buffer limit (16 * 6 = 96 floats vs 384)
#ifndef MAX_SHAPES
#define MAX_SHAPES 16
#endif

float sdfRRect( in vec2 p, in vec2 b, in float r ) {
    float shortest = min(b.x, b.y);
    r = min(r, shortest);
    vec2 q = abs(p)-b+r;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r;
}

float sdfRect(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdfSquircle(vec2 p, vec2 b, float r) {
    float shortest = min(b.x, b.y);
    r = min(r, shortest);

    vec2 q = abs(p) - b + r;
    
    vec2 maxQ = max(q, 0.0);
    return min(max(q.x, q.y), 0.0) + sqrt(maxQ.x * maxQ.x + maxQ.y * maxQ.y) - r;
}

float sdfEllipse(vec2 p, vec2 r) {
    r = max(r, 1e-4);
    
    vec2 invR = 1.0 / r;
    vec2 invR2 = invR * invR;
    
    vec2 pInvR = p * invR;
    float k1 = length(pInvR);
    
    vec2 pInvR2 = p * invR2;
    float k2 = length(pInvR2);
    
    return (k1 * (k1 - 1.0)) / max(k2, 1e-4);
}

float smoothUnion(float d1, float d2, float k) {
    if (k <= 0.0) {
        return min(d1, d2);
    }
    float e = max(k - abs(d1 - d2), 0.0);
    return min(d1, d2) - e * e * 0.25 / k;
}

float getShapeSDF(float type, vec2 p, vec2 center, vec2 size, float r) {
    if (type == 1.0) { // squircle
        return sdfSquircle(p - center, size / 2.0, r);
    }
    if (type == 2.0) { // ellipse
        return sdfEllipse(p - center, size / 2.0);
    }
    if (type == 3.0) { // rounded rectangle
        return sdfRRect(p - center, size / 2.0, r);
    }
    return 1e9; // none
}

float getShapeSDFFromArray(int index, vec2 p) {
    // Skia/SkSL require constant index expressions for array access.
    // We use literal constants in an if-chain to ensure cross-platform compatibility.
    if (index == 0) return getShapeSDF(uShapeData[0], p, vec2(uShapeData[1], uShapeData[2]), vec2(uShapeData[3], uShapeData[4]), uShapeData[5]);
    if (index == 1) return getShapeSDF(uShapeData[6], p, vec2(uShapeData[7], uShapeData[8]), vec2(uShapeData[9], uShapeData[10]), uShapeData[11]);
    if (index == 2) return getShapeSDF(uShapeData[12], p, vec2(uShapeData[13], uShapeData[14]), vec2(uShapeData[15], uShapeData[16]), uShapeData[17]);
    if (index == 3) return getShapeSDF(uShapeData[18], p, vec2(uShapeData[19], uShapeData[20]), vec2(uShapeData[21], uShapeData[22]), uShapeData[23]);
    if (index == 4) return getShapeSDF(uShapeData[24], p, vec2(uShapeData[25], uShapeData[26]), vec2(uShapeData[27], uShapeData[28]), uShapeData[29]);
    if (index == 5) return getShapeSDF(uShapeData[30], p, vec2(uShapeData[31], uShapeData[32]), vec2(uShapeData[33], uShapeData[34]), uShapeData[35]);
    if (index == 6) return getShapeSDF(uShapeData[36], p, vec2(uShapeData[37], uShapeData[38]), vec2(uShapeData[39], uShapeData[40]), uShapeData[41]);
    if (index == 7) return getShapeSDF(uShapeData[42], p, vec2(uShapeData[43], uShapeData[44]), vec2(uShapeData[45], uShapeData[46]), uShapeData[47]);
    if (index == 8) return getShapeSDF(uShapeData[48], p, vec2(uShapeData[49], uShapeData[50]), vec2(uShapeData[51], uShapeData[52]), uShapeData[53]);
    if (index == 9) return getShapeSDF(uShapeData[54], p, vec2(uShapeData[55], uShapeData[56]), vec2(uShapeData[57], uShapeData[58]), uShapeData[59]);
    if (index == 10) return getShapeSDF(uShapeData[60], p, vec2(uShapeData[61], uShapeData[62]), vec2(uShapeData[63], uShapeData[64]), uShapeData[65]);
    if (index == 11) return getShapeSDF(uShapeData[66], p, vec2(uShapeData[67], uShapeData[68]), vec2(uShapeData[69], uShapeData[70]), uShapeData[71]);
    if (index == 12) return getShapeSDF(uShapeData[72], p, vec2(uShapeData[73], uShapeData[74]), vec2(uShapeData[75], uShapeData[76]), uShapeData[77]);
    if (index == 13) return getShapeSDF(uShapeData[78], p, vec2(uShapeData[79], uShapeData[80]), vec2(uShapeData[81], uShapeData[82]), uShapeData[83]);
    if (index == 14) return getShapeSDF(uShapeData[84], p, vec2(uShapeData[85], uShapeData[86]), vec2(uShapeData[87], uShapeData[88]), uShapeData[89]);
    if (index == 15) return getShapeSDF(uShapeData[90], p, vec2(uShapeData[91], uShapeData[92]), vec2(uShapeData[93], uShapeData[94]), uShapeData[95]);
    
    return 1e9;
}

float sceneSDF(vec2 p, int numShapes, float blend) {
    if (numShapes == 0) {
        return 1e9;
    }
    
    float result = getShapeSDFFromArray(0, p);
    
    // Optimized: unroll for common cases (1-4 shapes), use loop for 5+ shapes
    if (numShapes <= 4) {
        // Fully unrolled for 1-4 shapes (covers 90%+ of use cases)
        if (numShapes >= 2) {
            float shapeSDF = getShapeSDFFromArray(1, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
        if (numShapes >= 3) {
            float shapeSDF = getShapeSDFFromArray(2, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
        if (numShapes >= 4) {
            float shapeSDF = getShapeSDFFromArray(3, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
    } else {
        // Dynamic loop for 5+ shapes (uncommon cases)
        // Fixed bound for Skia/SkSL compatibility
        for (int i = 1; i < MAX_SHAPES; i++) {
            if (i >= numShapes) break;
            float shapeSDF = getShapeSDFFromArray(i, p);
            result = smoothUnion(result, shapeSDF, blend);
        }
    }
    
    return result;
}

// Calculate 3D normal using numerical derivatives (portable across Windows/Web)
vec3 getNormal(vec2 p, int numShapes, float blend, float thickness) {
    // We use a small epsilon for numerical differentiation
    // This is more portable than dFdx/dFdy which aren't supported in all Flutter targets
    const float h = 0.5;
    
    float d = sceneSDF(p, numShapes, blend);
    
    // Central difference for better accuracy
    float dx = (sceneSDF(p + vec2(h, 0.0), numShapes, blend) - sceneSDF(p - vec2(h, 0.0), numShapes, blend)) / (2.0 * h);
    float dy = (sceneSDF(p + vec2(0.0, h), numShapes, blend) - sceneSDF(p - vec2(0.0, h), numShapes, blend)) / (2.0 * h);
    
    // The cosine and sine between normal and the xy plane
    float n_cos = max(thickness + d, 0.0) / thickness;
    float n_sin = sqrt(max(0.0, 1.0 - n_cos * n_cos));
    
    return normalize(vec3(dx * n_cos, dy * n_cos, n_sin));
}
