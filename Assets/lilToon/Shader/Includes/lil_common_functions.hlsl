#ifndef LIL_FUNCTIONS_INCLUDED
#define LIL_FUNCTIONS_INCLUDED

#include "lil_common_functions_thirdparty.hlsl"

//------------------------------------------------------------------------------------------------------------------------------
// Math

// Tooning
#if LIL_ANTIALIAS_MODE == 0
    float lilIsIn0to1(float f)
    {
        return saturate(f) == f;
    }

    float lilIsIn0to1(float f, float nv)
    {
        return saturate(f) == f;
    }

    float lilTooningNoSaturate(float value, float border)
    {
        return step(border, value);
    }

    float lilTooningNoSaturate(float value, float border, float blur)
    {
        float borderMin = saturate(border - blur * 0.5);
        float borderMax = saturate(border + blur * 0.5);
        return (value - borderMin) / saturate(borderMax - borderMin);
    }

    float lilTooningNoSaturate(float value, float border, float blur, float borderRange)
    {
        float borderMin = saturate(border - blur * 0.5 - borderRange);
        float borderMax = saturate(border + blur * 0.5);
        return (value - borderMin) / saturate(borderMax - borderMin);
    }

    float lilTooning(float value, float border)
    {
        return lilTooningNoSaturate(value, border);
    }

    float lilTooning(float value, float border, float blur)
    {
        return saturate(lilTooningNoSaturate(value, border, blur));
    }

    float lilTooning(float value, float border, float blur, float borderRange)
    {
        return saturate(lilTooningNoSaturate(value, border, blur, borderRange));
    }
#else
    float lilIsIn0to1(float f)
    {
        float value = 0.5 - abs(f-0.5);
        return saturate(value / clamp(fwidth(value), 0.0001, 1.0));
    }

    float lilIsIn0to1(float f, float nv)
    {
        float value = 0.5 - abs(f-0.5);
        return saturate(value / clamp(fwidth(value), 0.0001, nv));
    }

    float lilTooningNoSaturate(float value, float border)
    {
        return (value - border) / clamp(fwidth(value), 0.0001, 1.0);
    }

    float lilTooningNoSaturate(float value, float border, float blur)
    {
        float borderMin = saturate(border - blur * 0.5);
        float borderMax = saturate(border + blur * 0.5);
        return (value - borderMin) / saturate(borderMax - borderMin + fwidth(value));
    }

    float lilTooningNoSaturate(float value, float border, float blur, float borderRange)
    {
        float borderMin = saturate(border - blur * 0.5 - borderRange);
        float borderMax = saturate(border + blur * 0.5);
        return (value - borderMin) / saturate(borderMax - borderMin + fwidth(value));
    }

    float lilTooning(float value, float border)
    {
        return saturate(lilTooningNoSaturate(value, border));
    }

    float lilTooning(float value, float border, float blur)
    {
        return saturate(lilTooningNoSaturate(value, border, blur));
    }

    float lilTooning(float value, float border, float blur, float borderRange)
    {
        return saturate(lilTooningNoSaturate(value, border, blur, borderRange));
    }
#endif

// Optimized matrix calculation
float4 lilOptMul(float4x4 mat, float3 pos)
{
    return mat._m00_m10_m20_m30 * pos.x + (mat._m01_m11_m21_m31 * pos.y + (mat._m02_m12_m22_m32 * pos.z + mat._m03_m13_m23_m33));
}

// Check if the value is within range
float lilIsIn0to1(float2 f)
{
    return lilIsIn0to1(f.x) * lilIsIn0to1(f.y);
}

float lilIsIn0to1(float2 f, float nv)
{
    return lilIsIn0to1(f.x, nv) * lilIsIn0to1(f.y, nv);
}

// Normal blend in tangent space
float3 lilBlendNormal(float3 dstNormal, float3 srcNormal)
{
    return float3(dstNormal.xy + srcNormal.xy, dstNormal.z * srcNormal.z);
}

float lilMedian(float r, float g, float b)
{
    return max(min(r, g), min(max(r, g), b));
}

float lilMSDF(float3 msd)
{
    float sd = lilMedian(msd.r, msd.g, msd.b);
    return saturate((sd - 0.5)/clamp(fwidth(sd), 0.01, 1.0));
}

float lilIntervalTime(float interval)
{
    return floor(LIL_TIME / interval) * interval;
}

float lilNsqDistance(float2 a, float2 b)
{
    return dot(a-b,a-b);
}

float3 lilOrthoNormalize(float3 tangent, float3 normal)
{
    return normalize(tangent - normal * dot(normal, tangent));
}

float3 lilUnpackNormalScale(float4 normalTex, float scale)
{
    float3 normal;
    #if defined(UNITY_NO_DXT5nm)
        normal = normalTex.rgb * 2.0 - 1.0;
        normal.xy *= scale;
    #else
        #if !defined(UNITY_ASTC_NORMALMAP_ENCODING)
            normalTex.a *= normalTex.r;
        #endif
        normal.xy = normalTex.ag * 2.0 - 1.0;
        normal.xy *= scale;
        normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
    #endif
    return normal;
}

//------------------------------------------------------------------------------------------------------------------------------
// Position Transform
struct lilVertexPositionInputs
{
    float3 positionWS; // World space
    float3 positionVS; // View space
    float4 positionCS; // Clip space
    float4 positionSS; // Screen space
};

lilVertexPositionInputs lilGetVertexPositionInputs(float4 positionOS)
{
    lilVertexPositionInputs output;
    output.positionWS = lilTransformOStoWS(positionOS);
    output.positionVS = lilTransformWStoVS(output.positionWS);
    output.positionCS = lilTransformWStoCS(output.positionWS);
    output.positionSS = lilTransformCStoSS(output.positionCS);
    return output;
}

lilVertexPositionInputs lilGetVertexPositionInputs(float3 positionOS)
{
    return lilGetVertexPositionInputs(float4(positionOS, 1.0));
}

lilVertexPositionInputs lilReGetVertexPositionInputs(lilVertexPositionInputs output)
{
    output.positionVS = lilTransformWStoVS(output.positionWS);
    output.positionCS = lilTransformWStoCS(output.positionWS);
    output.positionSS = lilTransformCStoSS(output.positionCS);
    return output;
}

//------------------------------------------------------------------------------------------------------------------------------
// Normal Transform
struct lilVertexNormalInputs
{
    float3 tangentWS;
    float3 bitangentWS;
    float3 normalWS;
};

lilVertexNormalInputs lilGetVertexNormalInputs()
{
    lilVertexNormalInputs output;
    output.normalWS     = float3(1.0, 0.0, 0.0);
    output.tangentWS    = float3(1.0, 0.0, 0.0);
    output.bitangentWS  = float3(0.0, 1.0, 0.0);
    return output;
}

lilVertexNormalInputs lilGetVertexNormalInputs(float3 normalOS)
{
    lilVertexNormalInputs output;
    output.normalWS     = lilTransformNormalOStoWS(normalOS, true);
    output.tangentWS    = float3(1.0, 0.0, 0.0);
    output.bitangentWS  = float3(0.0, 1.0, 0.0);
    return output;
}

lilVertexNormalInputs lilGetVertexNormalInputs(float3 normalOS, float4 tangentOS)
{
    lilVertexNormalInputs output;
    output.normalWS     = lilTransformNormalOStoWS(normalOS, true);
    output.tangentWS    = lilTransformDirOStoWS(tangentOS.xyz, true);
    output.bitangentWS  = cross(output.normalWS, output.tangentWS) * (tangentOS.w * LIL_NEGATIVE_SCALE);
    return output;
}

//------------------------------------------------------------------------------------------------------------------------------
// Outline
float lilGetOutlineWidth(float2 uv, float4 color, float outlineWidth, TEXTURE2D(outlineWidthMask), uint outlineVertexR2Width LIL_SAMP_IN_FUNC(samp))
{
    outlineWidth *= 0.01;
    #if defined(LIL_FEATURE_OutlineWidthMask)
        outlineWidth *= LIL_SAMPLE_2D_LOD(outlineWidthMask, samp, uv, 0).r;
    #endif
    if(outlineVertexR2Width == 1) outlineWidth *= color.r;
    if(outlineVertexR2Width == 2) outlineWidth *= color.a;
    return outlineWidth;
}

float lilGetOutlineWidth(float3 positionOS, float3 positionWS, float2 uv, float4 color, float outlineWidth, TEXTURE2D(outlineWidthMask), uint outlineVertexR2Width, float outlineFixWidth LIL_SAMP_IN_FUNC(samp))
{
    outlineWidth = lilGetOutlineWidth(uv, color, outlineWidth, outlineWidthMask, outlineVertexR2Width LIL_SAMP_IN(samp));
    outlineWidth *= lerp(1.0, saturate(length(lilHeadDirection(positionWS))), outlineFixWidth);
    return outlineWidth;
}

float3 lilGetOutlineVector(float3x3 tbnOS, float2 uv, float outlineVectorScale, TEXTURE2D(outlineVectorTex) LIL_SAMP_IN_FUNC(samp))
{
    float3 outlineVector = lilUnpackNormalScale(LIL_SAMPLE_2D_LOD(outlineVectorTex, samp, uv, 0), outlineVectorScale);
    outlineVector = mul(outlineVector, tbnOS);
    return outlineVector;
}

void lilCalcOutlinePosition(inout float3 positionOS, float2 uvs[4], float4 color, float3 normalOS, float3x3 tbnOS, float outlineWidth, TEXTURE2D(outlineWidthMask), uint outlineVertexR2Width, float outlineFixWidth, float outlineZBias, float outlineVectorScale, uint outlineVectorUVMode, TEXTURE2D(outlineVectorTex) LIL_SAMP_IN_FUNC(samp))
{
    float3 positionWS = lilToAbsolutePositionWS(lilOptMul(LIL_MATRIX_M, positionOS).xyz);
    float width = lilGetOutlineWidth(positionOS, positionWS, uvs[0], color, outlineWidth, outlineWidthMask, outlineVertexR2Width, outlineFixWidth LIL_SAMP_IN(samp));
    float3 outlineN = normalOS;
    #if defined(LIL_FEATURE_OutlineVectorTex)
        outlineN = lilGetOutlineVector(tbnOS, uvs[outlineVectorUVMode], outlineVectorScale, outlineVectorTex LIL_SAMP_IN(samp));
    #endif
    if(outlineVertexR2Width == 2) outlineN = mul(color.rgb * 2.0 - 1.0, tbnOS);
    positionOS += outlineN * width;
    float3 V = lilIsPerspective() ? lilViewDirectionOS(positionOS) : mul((float3x3)LIL_MATRIX_I_M, LIL_MATRIX_V._m20_m21_m22);
    positionOS -= normalize(V) * outlineZBias;
}

void lilCalcOutlinePositionLite(inout float3 positionOS, float2 uv, float4 color, float3 normalOS, float3x3 tbnOS, float outlineWidth, TEXTURE2D(outlineWidthMask), uint outlineVertexR2Width, float outlineFixWidth, float outlineZBias LIL_SAMP_IN_FUNC(samp))
{
    float3 positionWS = lilToAbsolutePositionWS(lilOptMul(LIL_MATRIX_M, positionOS).xyz);
    float width = lilGetOutlineWidth(positionOS, positionWS, uv, color, outlineWidth, outlineWidthMask, outlineVertexR2Width, outlineFixWidth LIL_SAMP_IN(samp));
    float3 outlineN = normalOS;
    if(outlineVertexR2Width == 2) outlineN = mul(color.rgb * 2.0 - 1.0, tbnOS);
    positionOS += outlineN * width;
    float3 V = lilIsPerspective() ? lilViewDirectionOS(positionOS) : mul((float3x3)LIL_MATRIX_I_M, LIL_MATRIX_V._m20_m21_m22);
    positionOS -= normalize(V) * outlineZBias;
}

//------------------------------------------------------------------------------------------------------------------------------
// Color
float3 lilBlendColor(float3 dstCol, float3 srcCol, float3 srcA, uint blendMode)
{
    float3 ad = dstCol + srcCol;
    float3 mu = dstCol * srcCol;
    float3 outCol;
    if(blendMode == 0) outCol = srcCol;               // Normal
    if(blendMode == 1) outCol = ad;                   // Add
    if(blendMode == 2) outCol = max(ad - mu, dstCol); // Screen
    if(blendMode == 3) outCol = mu;                   // Multiply
    return lerp(dstCol, outCol, srcA);
}

float3 lilBlendColor(float3 dstCol, float3 srcCol, float srcA, uint blendMode)
{
    return lilBlendColor(dstCol, srcCol, float3(srcA,srcA,srcA), blendMode);
}

float lilGray(float3 rgb)
{
    return dot(rgb, float3(1.0/3.0, 1.0/3.0, 1.0/3.0));
}

float3 lilToneCorrection(float3 c, float4 hsvg)
{
    // gamma
    c = pow(abs(c), hsvg.w);
    // rgb -> hsv
    float4 p = (c.b > c.g) ? float4(c.bg,-1.0,2.0/3.0) : float4(c.gb,0.0,-1.0/3.0);
    float4 q = (p.x > c.r) ? float4(p.xyw, c.r) : float4(c.r, p.yzx);
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    float3 hsv = float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
    // shift
    hsv = float3(hsv.x+hsvg.x,saturate(hsv.y*hsvg.y),saturate(hsv.z*hsvg.z));
    // hsv -> rgb
    return hsv.z - hsv.z * hsv.y + hsv.z * hsv.y * saturate(abs(frac(hsv.x + float3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0) - 1.0);
}

float3 lilGradationMap(float3 col, TEXTURE2D(gradationMap), float strength)
{
    if(strength == 0.0) return col;
    #if !defined(LIL_COLORSPACE_GAMMA)
        col = lilLinearToSRGB(col);
    #endif
    float R = LIL_SAMPLE_1D(gradationMap, sampler_linear_clamp, col.r).r;
    float G = LIL_SAMPLE_1D(gradationMap, sampler_linear_clamp, col.g).g;
    float B = LIL_SAMPLE_1D(gradationMap, sampler_linear_clamp, col.b).b;
    float3 outrgb = float3(R,G,B);
    #if !defined(LIL_COLORSPACE_GAMMA)
        col = lilSRGBToLinear(col);
        outrgb = lilSRGBToLinear(outrgb);
    #endif
    return lerp(col, outrgb, strength);
}

float3 lilDecodeHDR(float4 data, float4 hdr)
{
    float alpha = hdr.w * (data.a - 1.0) + 1.0;

    #if defined(LIL_COLORSPACE_GAMMA)
        return (hdr.x * alpha) * data.rgb;
    #elif defined(UNITY_USE_NATIVE_HDR)
        return hdr.x * data.rgb;
    #else
        return (hdr.x * pow(abs(alpha), hdr.y)) * data.rgb;
    #endif
}

//------------------------------------------------------------------------------------------------------------------------------
// UV

// Rotation
float2 lilRotateUV(float2 uv, float2x2 rotMatrix)
{
    return mul(rotMatrix, uv - 0.5) + 0.5;
}

float2 lilRotateUV(float2 uv, float angle)
{
    float si,co;
    sincos(angle, si, co);
    float2 outuv = uv - 0.5;
    outuv = float2(
        outuv.x * co - outuv.y * si,
        outuv.x * si + outuv.y * co
    );
    outuv += 0.5;
    return outuv;
}

// Tiling, offset, animation calculations
float2 lilCalcUV(float2 uv, float4 uv_st)
{
    return uv * uv_st.xy + uv_st.zw;
}

float2 lilCalcUV(float2 uv, float4 uv_st, float angle)
{
    float2 outuv = uv * uv_st.xy + uv_st.zw;
    outuv = lilRotateUV(outuv, angle);
    return outuv;
}

float2 lilCalcUV(float2 uv, float4 uv_st, float2 uv_sr)
{
    return uv * uv_st.xy + uv_st.zw + frac(uv_sr * LIL_TIME);
}

float2 lilCalcUV(float2 uv, float4 uv_st, float4 uv_sr)
{
    float2 outuv = uv * uv_st.xy + uv_st.zw;
    outuv = lilRotateUV(outuv, uv_sr.z + uv_sr.w * LIL_TIME) + frac(uv_sr.xy * LIL_TIME);
    return outuv;
}

float2 lilCalcUVWithoutAnimation(float2 uv, float4 uv_st, float4 uv_sr)
{
    return lilRotateUV(uv * uv_st.xy + uv_st.zw, uv_sr.z);
}

float2 lilCalcDoubleSideUV(float2 uv, float facing, float shiftBackfaceUV)
{
    return facing < (shiftBackfaceUV-1.0) ? uv + float2(1.0,0.0) : uv;
}

// Decal
float2 lilCalcDecalUV(
    float2 uv,
    float4 uv_ST,
    float angle,
    bool isLeftOnly,
    bool isRightOnly,
    bool shouldCopy,
    bool shouldFlipMirror,
    bool shouldFlipCopy,
    bool isRightHand)
{
    float2 outUV = uv;

    // Copy
    if(shouldCopy) outUV.x = abs(outUV.x - 0.5) + 0.5;

    // Scale & Offset
    outUV = outUV * uv_ST.xy + uv_ST.zw;

    // Flip
    if(shouldFlipCopy && uv.x<0.5) outUV.x = 1.0 - outUV.x;
    if(shouldFlipMirror && isRightHand) outUV.x = 1.0 - outUV.x;

    // Hide
    if(isLeftOnly && isRightHand) outUV.x = -1.0;
    if(isRightOnly && !isRightHand) outUV.x = -1.0;

    // Rotate
    outUV = (outUV - uv_ST.zw) / uv_ST.xy;
    outUV = lilRotateUV(outUV, angle);
    outUV = outUV * uv_ST.xy + uv_ST.zw;

    return outUV;
}

float2 lilCalcAtlasAnimation(float2 uv, float4 decalAnimation, float4 decalSubParam)
{
    float2 outuv = lerp(float2(uv.x, 1.0-uv.y), 0.5, decalSubParam.z);
    uint animTime = (uint)(LIL_TIME * decalAnimation.w) % (uint)decalAnimation.z;
    uint offsetX = animTime % (uint)decalAnimation.x;
    uint offsetY = animTime / (uint)decalAnimation.x;
    outuv = (outuv + float2(offsetX,offsetY)) * decalSubParam.xy / decalAnimation.xy;
    outuv.y = 1.0-outuv.y;
    return outuv;
}

// MatCap
float2 lilCalcMatCapUV(float2 uv1, float3 normalWS, float3 viewDirection, float3 headDirection, float4 matcap_ST, float2 matcapBlendUV1, bool zRotCancel, bool matcapPerspective, float matcapVRParallaxStrength)
{
    // Simple
    //return mul((float3x3)LIL_MATRIX_V, normalWS).xy * 0.5 + 0.5;
    float3 normalVD = lilBlendVRParallax(headDirection, viewDirection, matcapVRParallaxStrength);
    normalVD = lilIsPerspective() && matcapPerspective ? normalVD : lilCameraDirection();
    float3 bitangentVD = zRotCancel ? float3(0,1,0) : LIL_MATRIX_V._m10_m11_m12;
    bitangentVD = lilOrthoNormalize(bitangentVD, normalVD);
    float3 tangentVD = cross(normalVD, bitangentVD);
    float3x3 tbnVD = float3x3(tangentVD, bitangentVD, normalVD);
    float2 uvMat = mul(tbnVD, normalWS).xy;
    uvMat = lerp(uvMat, uv1*2-1, matcapBlendUV1);
    uvMat = uvMat * matcap_ST.xy + matcap_ST.zw;
    uvMat = uvMat * 0.5 + 0.5;
    return uvMat;
}

// Panorama
float2 lilGetPanoramaUV(float3 viewDirection)
{
    return float2(lilAtan(viewDirection.x, viewDirection.z), lilAcos(viewDirection.y)) * LIL_INV_PI;
}

// Parallax
void lilParallax(inout float2 uvMain, inout float2 uv, lilBool useParallax, float2 parallaxOffset, TEXTURE2D(parallaxMap), float parallaxScale, float parallaxOffsetParam)
{
    LIL_BRANCH
    if(useParallax)
    {
        float height = (LIL_SAMPLE_2D_LOD(parallaxMap,sampler_linear_repeat,uvMain,0).r - parallaxOffsetParam) * parallaxScale;
        uvMain += height * parallaxOffset;
        uv += height * parallaxOffset;
    }
}

void lilPOM(inout float2 uvMain, inout float2 uv, lilBool useParallax, float4 uv_st, float3 parallaxViewDirection, TEXTURE2D(parallaxMap), float parallaxScale, float parallaxOffsetParam)
{
    #define LIL_POM_DETAIL 200
    LIL_BRANCH
    if(useParallax)
    {
        float height;
        float height2;
        float3 rayStep = -parallaxViewDirection;
        float3 rayPos = float3(uvMain, 1.0) + (1.0-parallaxOffsetParam) * parallaxScale * parallaxViewDirection;
        rayStep.xy *= uv_st.xy;
        rayStep = rayStep / LIL_POM_DETAIL;
        rayStep.z /= parallaxScale;

        for(int i = 0; i < LIL_POM_DETAIL * 2 * parallaxScale; ++i)
        {
            height2 = height;
            rayPos += rayStep;
            height = LIL_SAMPLE_2D_LOD(parallaxMap,sampler_linear_repeat,rayPos.xy,0).r;
            if(height >= rayPos.z) break;
        }

        float2 prevObjPoint = rayPos.xy - rayStep.xy;
        float nextHeight = height - rayPos.z;
        float prevHeight = height2 - rayPos.z + rayStep.z;

        float weight = nextHeight / (nextHeight - prevHeight);
        rayPos.xy = lerp(rayPos.xy, prevObjPoint, weight);

        uv += rayPos.xy - uvMain;
        uvMain = rayPos.xy;
    }
}

//------------------------------------------------------------------------------------------------------------------------------
// Effect
float lilCalcBlink(float4 blink)
{
    float outBlink = sin(LIL_TIME * blink.z + blink.w) * 0.5 + 0.5;
    if(blink.y > 0.5) outBlink = round(outBlink);
    return lerp(1.0, outBlink, blink.x);
}

void lilCalcDissolve(
    inout float alpha,
    inout float dissolveAlpha,
    float2 uv,
    float3 positionOS,
    float4 dissolveParams,
    float4 dissolvePos,
    TEXTURE2D(dissolveMask),
    float4 dissolveMask_ST
    LIL_SAMP_IN_FUNC(samp))
{
    if(dissolveParams.r)
    {
        float dissolveMaskVal = 1.0;
        if(dissolveParams.r == 1.0)
        {
            #if defined(LIL_FEATURE_DissolveMask)
                dissolveMaskVal = LIL_SAMPLE_2D(dissolveMask, samp, lilCalcUV(uv, dissolveMask_ST)).r;
            #else
                dissolveMaskVal = 1.0f;
            #endif
        }
        if(dissolveParams.r == 1.0)
        {
            dissolveAlpha = 1.0 - saturate(abs(dissolveMaskVal - dissolveParams.b) / dissolveParams.a);
            dissolveMaskVal = dissolveMaskVal > dissolveParams.b ? 1.0 : 0.0;
        }
        if(dissolveParams.r == 2.0)
        {
            dissolveAlpha = dissolveParams.g == 1.0 ? lilRotateUV(uv, dissolvePos.w).x : distance(uv, dissolvePos.xy);
            dissolveMaskVal *= dissolveAlpha > dissolveParams.b ? 1.0 : 0.0;
            dissolveAlpha = 1.0 - saturate(abs(dissolveAlpha - dissolveParams.b) / dissolveParams.a);
        }
        if(dissolveParams.r == 3.0)
        {
            dissolveAlpha = dissolveParams.g == 1.0 ? dot(positionOS, normalize(dissolvePos.xyz)).x : distance(positionOS, dissolvePos.xyz);
            dissolveMaskVal *= dissolveAlpha > dissolveParams.b ? 1.0 : 0.0;
            dissolveAlpha = 1.0 - saturate(abs(dissolveAlpha - dissolveParams.b) / dissolveParams.a);
        }
        alpha *= dissolveMaskVal;
    }
}

void lilCalcDissolveWithNoise(
    inout float alpha,
    inout float dissolveAlpha,
    float2 uv,
    float3 positionOS,
    float4 dissolveParams,
    float4 dissolvePos,
    TEXTURE2D(dissolveMask),
    float4 dissolveMask_ST,
    TEXTURE2D(dissolveNoiseMask),
    float4 dissolveNoiseMask_ST,
    float4 dissolveNoiseMask_ScrollRotate,
    float dissolveNoiseStrength
    LIL_SAMP_IN_FUNC(samp))
{
    if(dissolveParams.r)
    {
        float dissolveMaskVal = 1.0;
        float dissolveNoise = 0.0;
        if(dissolveParams.r == 1.0)
        {
            #if defined(LIL_FEATURE_DissolveMask)
                dissolveMaskVal = LIL_SAMPLE_2D(dissolveMask, samp, lilCalcUV(uv, dissolveMask_ST)).r;
            #else
                dissolveMaskVal = 1.0f;
            #endif
        }
        dissolveNoise = LIL_SAMPLE_2D(dissolveNoiseMask, samp, lilCalcUV(uv, dissolveNoiseMask_ST, dissolveNoiseMask_ScrollRotate.xy)).r - 0.5;
        dissolveNoise *= dissolveNoiseStrength;
        if(dissolveParams.r == 1.0)
        {
            dissolveAlpha = 1.0 - saturate(abs(dissolveMaskVal + dissolveNoise - dissolveParams.b) / dissolveParams.a);
            dissolveMaskVal = dissolveMaskVal + dissolveNoise > dissolveParams.b ? 1.0 : 0.0;
        }
        if(dissolveParams.r == 2.0)
        {
            dissolveAlpha = dissolveParams.g == 1.0 ? dot(uv, normalize(dissolvePos.xy)) + dissolveNoise : distance(uv, dissolvePos.xy) + dissolveNoise;
            dissolveMaskVal *= dissolveAlpha > dissolveParams.b ? 1.0 : 0.0;
            dissolveAlpha = 1.0 - saturate(abs(dissolveAlpha - dissolveParams.b) / dissolveParams.a);
        }
        if(dissolveParams.r == 3.0)
        {
            dissolveAlpha = dissolveParams.g == 1.0 ? dot(positionOS, normalize(dissolvePos.xyz)) + dissolveNoise : distance(positionOS, dissolvePos.xyz) + dissolveNoise;
            dissolveMaskVal *= dissolveAlpha > dissolveParams.b ? 1.0 : 0.0;
            dissolveAlpha = 1.0 - saturate(abs(dissolveAlpha - dissolveParams.b) / dissolveParams.a);
        }
        alpha *= dissolveMaskVal;
    }
}

//------------------------------------------------------------------------------------------------------------------------------
// Sub Texture
float4 lilGetSubTex(
    TEXTURE2D(tex),
    float4 uv_ST,
    float angle,
    float2 uv,
    float nv,
    bool isDecal,
    bool isLeftOnly,
    bool isRightOnly,
    bool shouldCopy,
    bool shouldFlipMirror,
    bool shouldFlipCopy,
    bool isMSDF,
    bool isRightHand,
    float4 decalAnimation,
    float4 decalSubParam
    LIL_SAMP_IN_FUNC(samp))
{
    #if defined(LIL_FEATURE_DECAL)
        float2 uv2 = lilCalcDecalUV(uv, uv_ST, angle, isLeftOnly, isRightOnly, shouldCopy, shouldFlipMirror, shouldFlipCopy, isRightHand);
        #if defined(LIL_FEATURE_ANIMATE_DECAL)
            float2 uv2samp = lilCalcAtlasAnimation(uv2, decalAnimation, decalSubParam);
        #else
            float2 uv2samp = uv2;
        #endif
        float4 outCol = LIL_SAMPLE_2D(tex,samp,uv2samp);
        LIL_BRANCH
        if(isMSDF) outCol = float4(1.0, 1.0, 1.0, lilMSDF(outCol.rgb));
        LIL_BRANCH
        if(isDecal) outCol.a *= lilIsIn0to1(uv2, saturate(nv-0.05));
        return outCol;
    #else
        float2 uv2 = lilCalcUV(uv, uv_ST, angle);
        float4 outCol = LIL_SAMPLE_2D(tex,samp,uv2);
        LIL_BRANCH
        if(isMSDF) outCol = float4(1.0, 1.0, 1.0, lilMSDF(outCol.rgb));
        return outCol;
    #endif
}

float4 lilGetSubTexWithoutAnimation(
    TEXTURE2D(tex),
    float4 uv_ST,
    float angle,
    float2 uv,
    float nv,
    bool isDecal,
    bool isLeftOnly,
    bool isRightOnly,
    bool shouldCopy,
    bool shouldFlipMirror,
    bool shouldFlipCopy,
    bool isMSDF,
    bool isRightHand
    LIL_SAMP_IN_FUNC(samp))
{
    #if defined(LIL_FEATURE_DECAL)
        float2 uv2 = lilCalcDecalUV(uv, uv_ST, angle, isLeftOnly, isRightOnly, shouldCopy, shouldFlipMirror, shouldFlipCopy, isRightHand);
        float4 outCol = LIL_SAMPLE_2D(tex,samp,uv2);
        LIL_BRANCH
        if(isMSDF) outCol = float4(1.0, 1.0, 1.0, lilMSDF(outCol.rgb));
        LIL_BRANCH
        if(isDecal) outCol.a *= lilIsIn0to1(uv2, saturate(nv-0.05));
        return outCol;
    #else
        float2 uv2 = lilCalcUV(uv, uv_ST, angle);
        float4 outCol = LIL_SAMPLE_2D(tex,samp,uv2);
        LIL_BRANCH
        if(isMSDF) outCol = float4(1.0, 1.0, 1.0, lilMSDF(outCol.rgb));
        return outCol;
    #endif
}

//------------------------------------------------------------------------------------------------------------------------------
// Light Direction
float3 lilGetCustomLightDirection(float4 lightDirectionOverride)
{
    float3 customDir = length(lightDirectionOverride.xyz) * normalize(mul((float3x3)LIL_MATRIX_M, lightDirectionOverride.xyz));
    return lightDirectionOverride.w ? customDir : lightDirectionOverride.xyz;
}

float3 lilGetLightDirection(float4 lightDirectionOverride)
{
    return normalize(LIL_MAINLIGHT_DIRECTION * lilLuminance(LIL_MAINLIGHT_COLOR) + 
                    unity_SHAr.xyz * 0.333333 + unity_SHAg.xyz * 0.333333 + unity_SHAb.xyz * 0.333333 + 
                    lilGetCustomLightDirection(lightDirectionOverride));
}

float3 lilGetFixedLightDirection(float4 lightDirectionOverride, bool doNormalise)
{
    float3 L = unity_SHAr.xyz * 0.333333 + unity_SHAg.xyz * 0.333333 + unity_SHAb.xyz * 0.333333;
    L.y = abs(L.y);
    L += LIL_MAINLIGHT_DIRECTION * lilLuminance(LIL_MAINLIGHT_COLOR);
    L += lilGetCustomLightDirection(lightDirectionOverride);
    return doNormalise ? normalize(L) : L;
}

float3 lilGetFixedLightDirection(float4 lightDirectionOverride)
{
    return lilGetFixedLightDirection(lightDirectionOverride, true);
}

float3 lilGetLightDirection()
{
    return lilGetLightDirection(float4(0.0,0.001,0.0,0.0));
}

float3 lilGetLightDirection(float3 positionWS)
{
    #if defined(POINT) || defined(SPOT) || defined(POINT_COOKIE)
        return normalize(LIL_MAINLIGHT_DIRECTION - positionWS);
    #else
        return LIL_MAINLIGHT_DIRECTION;
    #endif
}

//------------------------------------------------------------------------------------------------------------------------------
// SH Lighting
float3 lilShadeSH9(float4 normalWS)
{
    float3 res;
    res.r = dot(unity_SHAr,normalWS);
    res.g = dot(unity_SHAg,normalWS);
    res.b = dot(unity_SHAb,normalWS);
    float4 vB = normalWS.xyzz * normalWS.yzzx;
    res.r += dot(unity_SHBr,vB);
    res.g += dot(unity_SHBg,vB);
    res.b += dot(unity_SHBb,vB);
    res += unity_SHC.rgb * (normalWS.x * normalWS.x - normalWS.y * normalWS.y);
    #ifdef LIL_COLORSPACE_GAMMA
        res = lilLinearToSRGB(res);
    #endif
    return res;
}

float3 lilShadeSH9(float3 normalWS)
{
    return lilShadeSH9(float4(normalWS,1.0));
}

float3 lilShadeSH9LPPV(float4 normalWS, float3 positionWS)
{
    float4 SHAr = unity_SHAr;
    float4 SHAg = unity_SHAg;
    float4 SHAb = unity_SHAb;
    #if defined(LIL_USE_LPPV)
        if(unity_ProbeVolumeParams.x == 1.0)
        {
            float3 position = (unity_ProbeVolumeParams.y == 1.0) ? lilOptMul(unity_ProbeVolumeWorldToObject, positionWS).xyz : positionWS;
            float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;
            texCoord.x = texCoord.x * 0.25;
            float texCoordX = clamp(texCoord.x, 0.5 * unity_ProbeVolumeParams.z, 0.25 - 0.5 * unity_ProbeVolumeParams.z);
            texCoord.x = texCoordX;
            SHAr = LIL_SAMPLE_3D(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH, texCoord);
            texCoord.x = texCoordX + 0.25;
            SHAg = LIL_SAMPLE_3D(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH, texCoord);
            texCoord.x = texCoordX + 0.5;
            SHAb = LIL_SAMPLE_3D(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH, texCoord);
        }
    #endif
    float3 res;
    res.r = dot(SHAr,normalWS);
    res.g = dot(SHAg,normalWS);
    res.b = dot(SHAb,normalWS);
    float4 vB = normalWS.xyzz * normalWS.yzzx;
    res.r += dot(unity_SHBr,vB);
    res.g += dot(unity_SHBg,vB);
    res.b += dot(unity_SHBb,vB);
    res += unity_SHC.rgb * (normalWS.x * normalWS.x - normalWS.y * normalWS.y);
    #ifdef LIL_COLORSPACE_GAMMA
        res = lilLinearToSRGB(res);
    #endif
    return res;
}

float3 lilShadeSH9LPPV(float3 normalWS, float3 positionWS)
{
    return lilShadeSH9LPPV(float4(normalWS,1.0), positionWS);
}

float3 lilGetSHToon(float4 lightDirectionOverride)
{
    return lilShadeSH9(lilGetLightDirection(lightDirectionOverride) * 0.666666);
}

float3 lilGetSHToon()
{
    return lilGetSHToon(float4(0.0,0.001,0.0,0.0));
}

float3 lilGetSHToon(float3 positionWS, float4 lightDirectionOverride)
{
    return lilShadeSH9LPPV(lilGetLightDirection(lightDirectionOverride) * 0.666666, positionWS);
}

float3 lilGetSHToon(float3 positionWS)
{
    return lilGetSHToon(positionWS, float4(0.0,0.001,0.0,0.0));
}

float3 lilGetSHToonMin(float4 lightDirectionOverride)
{
    return lilShadeSH9(-lilGetLightDirection(lightDirectionOverride) * 0.666666);
}

float3 lilGetSHToonMin()
{
    return lilGetSHToonMin(float4(0.0,0.001,0.0,0.0));
}

float3 lilGetSHToonMin(float3 positionWS, float4 lightDirectionOverride)
{
    return lilShadeSH9LPPV(-lilGetLightDirection(lightDirectionOverride) * 0.666666, positionWS);
}

float3 lilGetSHToonMin(float3 positionWS)
{
    return lilGetSHToonMin(positionWS, float4(0.0,0.001,0.0,0.0));
}

void lilGetToonSHDouble(float3 lightDirection, out float3 shMax, out float3 shMin)
{
    float3 N = lightDirection * 0.666666;
    float4 vB = N.xyzz * N.yzzx;
    // L0 L2
    float3 res = float3(unity_SHAr.w,unity_SHAg.w,unity_SHAb.w);
    res.r += dot(unity_SHBr, vB);
    res.g += dot(unity_SHBg, vB);
    res.b += dot(unity_SHBb, vB);
    res += unity_SHC.rgb * (N.x * N.x - N.y * N.y);
    // L1
    float3 l1;
    l1.r = dot(unity_SHAr.rgb, N);
    l1.g = dot(unity_SHAg.rgb, N);
    l1.b = dot(unity_SHAb.rgb, N);
    shMax = res + l1;
    shMin = res - l1;
    #ifdef LIL_COLORSPACE_GAMMA
        shMax = lilLinearToSRGB(shMax);
        shMin = lilLinearToSRGB(shMin);
    #endif
}

void lilGetToonSHDoubleLPPV(float3 lightDirection, float3 positionWS, out float3 shMax, out float3 shMin)
{
    float4 SHAr = unity_SHAr;
    float4 SHAg = unity_SHAg;
    float4 SHAb = unity_SHAb;
    #if defined(LIL_USE_LPPV)
        if(unity_ProbeVolumeParams.x == 1.0)
        {
            float3 position = (unity_ProbeVolumeParams.y == 1.0) ? lilOptMul(unity_ProbeVolumeWorldToObject, positionWS).xyz : positionWS;
            float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;
            texCoord.x = texCoord.x * 0.25;
            float texCoordX = clamp(texCoord.x, 0.5 * unity_ProbeVolumeParams.z, 0.25 - 0.5 * unity_ProbeVolumeParams.z);
            texCoord.x = texCoordX;
            SHAr = LIL_SAMPLE_3D(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH, texCoord);
            texCoord.x = texCoordX + 0.25;
            SHAg = LIL_SAMPLE_3D(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH, texCoord);
            texCoord.x = texCoordX + 0.5;
            SHAb = LIL_SAMPLE_3D(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH, texCoord);
        }
    #endif
    float3 N = lightDirection * 0.666666;
    float4 vB = N.xyzz * N.yzzx;
    // L0 L2
    float3 res = float3(SHAr.w,SHAg.w,SHAb.w);
    res.r += dot(unity_SHBr, vB);
    res.g += dot(unity_SHBg, vB);
    res.b += dot(unity_SHBb, vB);
    res += unity_SHC.rgb * (N.x * N.x - N.y * N.y);
    // L1
    float3 l1;
    l1.r = dot(SHAr.rgb, N);
    l1.g = dot(SHAg.rgb, N);
    l1.b = dot(SHAb.rgb, N);
    shMax = res + l1;
    shMin = res - l1;
    #ifdef LIL_COLORSPACE_GAMMA
        shMax = lilLinearToSRGB(shMax);
        shMin = lilLinearToSRGB(shMin);
    #endif
}

//------------------------------------------------------------------------------------------------------------------------------
// Lighting
float3 lilGetLightColor()
{
    return LIL_MAINLIGHT_COLOR + lilGetSHToon();
}

float3 lilGetLightColor(float3 positionWS)
{
    return LIL_MAINLIGHT_COLOR + lilGetSHToon(positionWS);
}

float3 lilGetIndirLightColor()
{
    return saturate(lilGetSHToonMin());
}

float3 lilGetIndirLightColor(float3 positionWS)
{
    return saturate(lilGetSHToonMin(positionWS));
}

void lilGetLightColorDouble(float3 lightDirection, out float3 lightColor, out float3 indLightColor)
{
    float3 shMax, shMin;
    lilGetToonSHDouble(lightDirection, shMax, shMin);
    lightColor = LIL_MAINLIGHT_COLOR + shMax;
    indLightColor = saturate(shMin);
}

//------------------------------------------------------------------------------------------------------------------------------
// Geometric Specular Antialiasing
void GSAA(inout float roughness, float3 N, float strength)
{
    float3 dx = abs(ddx(N));
    float3 dy = abs(ddy(N));
    float dxy = max(dot(dx,dx), dot(dy,dy));
    float roughnessGSAA = dxy / (dxy * 5 + 0.002) * strength;
    roughness = max(roughness, roughnessGSAA);
}

void GSAAForSmoothness(inout float smoothness, float3 N, float strength)
{
    float roughness = 0;
    GSAA(roughness, N, strength);
    smoothness = min(smoothness, saturate(1-roughness));
}

//------------------------------------------------------------------------------------------------------------------------------
// Specular
float3 lilFresnelTerm(float3 F0, float cosA)
{
    float a = 1.0-cosA;
    return F0 + (1-F0) * a * a * a * a * a;
}

float3 lilFresnelLerp(float3 F0, float3 F90, float cosA)
{
    float a = 1.0-cosA;
    return lerp(F0, F90, a * a * a * a * a);
}

float3 lilGetAnisotropyNormalWS(float3 normalWS, float3 anisoTangentWS, float3 anisoBitangentWS, float3 viewDirection, float anisotropy)
{
    float3 anisoDirectionWS = anisotropy > 0.0 ? anisoBitangentWS : anisoTangentWS;
    anisoDirectionWS = lilOrthoNormalize(viewDirection, anisoDirectionWS);
    return normalize(lerp(normalWS, anisoDirectionWS, abs(anisotropy)));
}

//------------------------------------------------------------------------------------------------------------------------------
// Reflection
float3 lilCustomReflection(TEXTURECUBE(tex), float4 hdr, float3 viewDirection, float3 normalDirection, float perceptualRoughness)
{
    float mip = perceptualRoughness * (10.2 - 4.2 * perceptualRoughness);
    float3 refl = reflect(-viewDirection, normalDirection);
    return lilDecodeHDR(LIL_SAMPLE_CUBE_LOD(tex, sampler_linear_repeat, refl, mip), hdr);
}

//------------------------------------------------------------------------------------------------------------------------------
// Glitter
float4 lilVoronoi(float2 pos, out float2 nearoffset, float scaleRandomize)
{
    #if defined(SHADER_API_D3D9) || defined(SHADER_API_D3D11_9X)
        #define M1 46203.4357
        #define M2 21091.5327
        #define M3 35771.1966
        float2 q = trunc(pos);
        float4 q2 = float4(q.x, q.y, q.x+1, q.y+1);
        float3 noise0 = frac(sin(dot(q2.xy,float2(12.9898,78.233))) * float3(M1, M2, M3));
        float3 noise1 = frac(sin(dot(q2.zy,float2(12.9898,78.233))) * float3(M1, M2, M3));
        float3 noise2 = frac(sin(dot(q2.xw,float2(12.9898,78.233))) * float3(M1, M2, M3));
        float3 noise3 = frac(sin(dot(q2.zw,float2(12.9898,78.233))) * float3(M1, M2, M3));
        #undef M1
        #undef M2
        #undef M3
    #else
        float3 noise0, noise1, noise2, noise3;
        lilHashRGB4(pos, noise0, noise1, noise2, noise3);
    #endif

    // Get the nearest position
    float4 fracpos = frac(pos).xyxy + float4(0.5,0.5,-0.5,-0.5);
    float4 dist4 = float4(lilNsqDistance(fracpos.xy,noise0.xy), lilNsqDistance(fracpos.zy,noise1.xy), lilNsqDistance(fracpos.xw,noise2.xy), lilNsqDistance(fracpos.zw,noise3.xy));
    dist4 = lerp(dist4, dist4 / max(float4(noise0.z, noise1.z, noise2.z, noise3.z), 0.001), scaleRandomize);

    float3 nearoffset0 = dist4.x < dist4.y ? float3(0,0,dist4.x) : float3(1,0,dist4.y);
    float3 nearoffset1 = dist4.z < dist4.w ? float3(0,1,dist4.z) : float3(1,1,dist4.w);
    nearoffset = nearoffset0.z < nearoffset1.z ? nearoffset0.xy : nearoffset1.xy;

    float4 near0 = dist4.x < dist4.y ? float4(noise0,dist4.x) : float4(noise1,dist4.y);
    float4 near1 = dist4.z < dist4.w ? float4(noise2,dist4.z) : float4(noise3,dist4.w);
    return near0.w < near1.w ? near0 : near1;
}

float3 lilCalcGlitter(float2 uv, float3 normalDirection, float3 viewDirection, float3 cameraDirection, float3 lightDirection, float4 glitterParams1, float4 glitterParams2, float glitterPostContrast, float glitterSensitivity, float glitterScaleRandomize, uint glitterAngleRandomize, bool glitterApplyShape, TEXTURE2D(glitterShapeTex), float4 glitterShapeTex_ST, float4 glitterAtras)
{
    // glitterParams1
    // x: Scale, y: Scale, z: Size, w: Contrast
    // glitterParams2
    // x: Speed, y: Angle, z: Light Direction, w:

    #define GLITTER_DEBUG_MODE 0
    #define GLITTER_MIPMAP 1
    #define GLITTER_ANTIALIAS 1

    #if GLITTER_MIPMAP == 1
        float2 pos = uv * glitterParams1.xy;
        float2 dd = fwidth(pos);
        float factor = frac(sin(dot(floor(pos/floor(dd + 3.0)),float2(12.9898,78.233))) * 46203.4357) + 0.5;
        float2 factor2 = floor(dd + factor * 0.5);
        pos = pos/max(1.0,factor2) + glitterParams1.xy * factor2;
    #else
        float2 pos = uv * glitterParams1.xy + glitterParams1.xy;
    #endif
    float2 nearoffset;
    float4 near = lilVoronoi(pos, nearoffset, glitterScaleRandomize);
    

    #if GLITTER_DEBUG_MODE == 1
        // Voronoi
        return near.x;
    #else
        // Glitter
        float3 glitterNormal = abs(frac(near.xyz*14.274 + _Time.x * glitterParams2.x) * 2.0 - 1.0);
        glitterNormal = normalize(glitterNormal * 2.0 - 1.0);
        float glitter = dot(glitterNormal, cameraDirection);
        glitter = abs(frac(glitter * glitterSensitivity + glitterSensitivity) - 0.5) * 4.0 - 1.0;
        glitter = saturate(1.0 - (glitter * glitterParams1.w + glitterParams1.w));
        glitter = pow(glitter, glitterPostContrast);
        // Circle
        #if GLITTER_ANTIALIAS == 1
            glitter *= saturate((glitterParams1.z-near.w) / fwidth(near.w));
        #else
            glitter = near.w < glitterParams1.z ? glitter : 0.0;
        #endif
        // Angle
        float3 halfDirection = normalize(viewDirection + lightDirection * glitterParams2.z);
        float nh = saturate(dot(normalDirection, halfDirection));
        glitter = saturate(glitter * saturate(nh * glitterParams2.y + 1.0 - glitterParams2.y));
        // Random Color
        float3 glitterColor = glitter - glitter * frac(near.xyz*278.436) * glitterParams2.w;
        // Shape
        #if defined(LIL_FEATURE_GlitterShapeTex)
            if(glitterApplyShape)
            {
                float2 maskUV = pos - floor(pos) - nearoffset + 0.5 - near.xy;
                maskUV = maskUV / glitterParams1.z * glitterShapeTex_ST.xy + glitterShapeTex_ST.zw;
                if(glitterAngleRandomize)
                {
                    float si,co;
                    sincos(near.z * 785.238, si, co);
                    maskUV = float2(
                        maskUV.x * co - maskUV.y * si,
                        maskUV.x * si + maskUV.y * co
                    );
                }
                float randomScale = lerp(1.0, 1.0 / sqrt(max(near.z, 0.001)), glitterScaleRandomize);
                maskUV = maskUV * randomScale + 0.5;
                bool clamp = maskUV.x == saturate(maskUV.x) && maskUV.y == saturate(maskUV.y);
                maskUV = (maskUV + floor(near.xy * glitterAtras.xy)) / glitterAtras.xy;
                float2 mipfactor = 0.125 / glitterParams1.z * glitterAtras.xy * glitterShapeTex_ST.xy * randomScale;
                float4 shapeTex = LIL_SAMPLE_2D_GRAD(glitterShapeTex, sampler_linear_clamp, maskUV, abs(ddx(pos)) * mipfactor.x, abs(ddy(pos)) * mipfactor.y);
                shapeTex.a = clamp ? shapeTex.a : 0;
                glitterColor *= shapeTex.rgb * shapeTex.a;
            }
        #endif
        return glitterColor;
    #endif
}

//------------------------------------------------------------------------------------------------------------------------------
// Tessellation
float lilCalcEdgeTessFactor(float3 wpos0, float3 wpos1, float edgeLen)
{
    float dist = distance(0.5 * (wpos0+wpos1), _WorldSpaceCameraPos.xyz);
    return max(distance(wpos0, wpos1) * LIL_SCREENPARAMS.y / (edgeLen * dist), 1.0);
}

#endif