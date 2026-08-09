import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects.private

// LiquidCard v3 — real liquid glass (hyprglass port).
// The glass body is a custom fragment shader (ported from hyprnux/hyprglass's
// liquidglass.frag): rounded-box SDF edge detection → edge refraction pulling
// the blurred art backdrop inward, per-channel chromatic aberration, a subtle
// center dome lens, frosted tone mapping (saturation → vibrancy → brightness →
// contrast → adaptive dim/boost), a tint overlay, fresnel rim glow, a top
// specular highlight and a bottom inner shadow. Layered highlights, the slow
// drifting reflection, film grain and the hairline edge complete the material.
//
// QML limitation: a layer surface cannot sample the live desktop behind it, so
// the shader samples the blurred art backdrop ("artUrl") instead — that is the
// "content" the glass refracts. Without a backdrop it falls back to a flat
// tinted glass plate.
Item {
    id: root

    property real cornerRadius: 18
    property bool hovered: false
    property real glowStrength: root.hovered ? 0.55 : 0
    Behavior on glowStrength { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    property color tint: "#8899AA"
    property real tintOpacity: 0.04
    property real borderOpacity: 0.35
    property real sheenStrength: 1.0
    property color surfaceColor: Qt.rgba(0.06, 0.065, 0.09, 1.0)

    // 0..1 — translucency of the glass body. Higher = more opaque glass plate
    // (the art backdrop / desktop blur show through less). 0.9 keeps the card
    // readable while a hint of the compositor blur still shines through.
    property real surfaceOpacity: 0.0

    // 0..1 — morph/elevation drive: scales the drop shadow + hover lift so the
    // card "lifts" as it materializes from the pill.
    property real elevation: 1.0

    // Blurred album-art backdrop (pass the pre-blurred path from music_info.sh)
    property string artUrl: ""
    property real artOpacity: 0.55

    // Exact backdrop stretch (px) for pixel-perfect capture alignment. When the
    // backdrop is grim-captured to a known on-screen region, the image rect must
    // match it exactly or refracted content misaligns. 0 = derive from padFraction.
    property real marginOverride: 0

    // Film grain (0 disables). Set ~0.4 for music.
    property real noiseOpacity: 0.0

    property bool driftEnabled: true
    property bool breathing: true

    // Concave ("inverted") corners — e.g. "topRight" so a popup hugs its trigger.
    // Empty string keeps the classic rounded card (no layering cost).
    property string invertedCorners: ""
    property real invertedRadius: 22

    // ---- Liquid glass material (ShojiWM liquid-glass.frag port) ----
    // glassOpacity doubles as the transparency dial: the shader only ever adds
    // glass (tint/specular/refraction) at this alpha, so the live desktop
    // behind the overlay shows through the rest — real glass.
    property real glassOpacity: 1.0
    property real edgeThickness: 0.06        // fraction of min dimension
    // "Just liquid glass" dials: the card body stays transparent (centerOpacity
    // = how much glass veil in the middle; you see the desktop through it) and
    // the liquid material (refraction/chromatic/sheen) lives in an edge ring
    // whose width is `liquidDepth` (fraction of min dimension).
    property real liquidDepth: 0.18
    property real centerOpacity: 0.0
    // Dome lens (ShojiWM): distortion_depth/distortion_strength/chromatic_shift_px
    property real distortionDepth: 0.4       // dome reach, fraction of min dim
    property real distortionStrength: 0.4
    property real chromaticShiftPx: 4.0
    property real fresnelStrength: 0.8       // edge rim glow
    property real specularStrength: 1.1      // top highlight / depth
    // Tone mapping (gentle — the backdrop already carries the desktop look)
    property real brightness: 1.0
    property real contrast: 1.0
    property real saturation: 1.0
    property real vibrancy: 0.2
    property real vibrancyDarkness: 0.0
    property real adaptiveDim: 0.03          // barely-there dim of bright areas
    property real adaptiveBoost: 0.0         // gentle lift of dark areas
    property real roundingPower: 4.0         // squircle exponent for the SDF

    property real tintOpacityHover: Math.min(tintOpacity + 0.05, 0.6)
    property real borderOpacityHover: Math.min(borderOpacity + 0.1, 0.7)
    property real sheenStrengthHover: sheenStrength + 0.3

    readonly property real effElevation: root.elevation * (root.hovered ? 1.18 : 1.0)

    // Idle breathing: a barely-perceptible glow shimmer (~6s cycle)
    property real breath: 0.5
    SequentialAnimation on breath {
        running: root.breathing
        loops: Animation.Infinite
        NumberAnimation { to: 1.0; duration: 3000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 3000; easing.type: Easing.InOutSine }
    }

    default property alias content: contentSlot.data

    // Soft drop shadow — mathematically smooth, no banding. Scales with elevation.
    RectangularShadow {
        anchors.fill: root
        offset: Qt.point(0, 4 + 4 * root.effElevation)
        blur: 10 + 8 * root.effElevation
        spread: -6
        radius: root.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.12 * root.effElevation)
        Behavior on offset { PropertyAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on blur { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 250 } }
    }

    // Premium hover glow — soft white halo, shader-smoothed (no pixels)
    RectangularShadow {
        anchors.fill: root
        offset: Qt.point(0, 0)
        blur: 16
        spread: 2
        radius: root.cornerRadius + 2
        color: Qt.rgba(1.0, 1.0, 1.0, root.glowStrength + root.breath * 0.04)
    }

    // ---- Liquid glass surface ----
    Rectangle {
        id: glass
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        clip: true

        layer.enabled: root.invertedCorners !== ""
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: root.invertedCorners !== ""
            maskSource: silhouette
        }

        // === Liquid-glass body (hyprglass liquidglass.frag port) ===
        ShaderEffect {
            id: liquidGlass
            anchors.fill: parent

            property vector2d fullSize: Qt.vector2d(width, height)
            property real radius: root.cornerRadius
            property real edgeThickness: root.edgeThickness
            property real distortionDepth: root.distortionDepth
            property real distortionStrength: root.distortionStrength
            property real chromaticShiftPx: root.chromaticShiftPx
            property real fresnelStrength: root.fresnelStrength
            property real specularStrength: root.specularStrength
            property real glassOpacity: root.glassOpacity
            property real liquidDepth: root.liquidDepth
            property real centerOpacity: root.centerOpacity
            property color tintColor: root.tint
            property real tintAlpha: root.tintOpacity
            property real brightness: root.brightness
            property real contrast: root.contrast
            property real saturation: root.saturation
            property real vibrancy: root.vibrancy
            property real vibrancyDarkness: root.vibrancyDarkness
            property real adaptiveDim: root.adaptiveDim
            property real adaptiveBoost: root.adaptiveBoost
            property real roundingPower: root.roundingPower

            // Backdrop mapping: the source image is stretched beyond the card by
            // `padFraction` so edge refraction can pull in real content from
            // beyond the boundary (mirrors hyprglass's SAMPLE_PADDING_PX).
            property real padFraction: 0.15
            // Exact backdrop stretch override (px). When a backdrop is captured
            // to a known on-screen region (fit-margin), the image rect must match
            // it pixel-perfect or the refracted content misaligns. 0 = derive.
            property real marginOverride: root.marginOverride
            readonly property real _margin: marginOverride > 0
                ? marginOverride
                : Math.max(parent.width, parent.height) * padFraction
            readonly property real padX: parent.width  > 0 ? _margin / (parent.width  + 2 * _margin) : 0
            readonly property real padY: parent.height > 0 ? _margin / (parent.height + 2 * _margin) : 0
            property real hasBackdrop: artBackdrop.status === Image.Ready ? 1.0 : 0.0

            property variant source: backdropSource

            // Shader source (GLSL #version 440). Qt 6 requires shaders to be
            // baked with qsb — ShaderBuilder (Qt5Compat.GraphicalEffects.private)
            // does that at runtime, exactly like Qt's own effects. All custom
            // uniforms live inside the `buf` block after qt_Opacity because
            // non-opaque uniforms are only allowed in blocks under Vulkan.
            readonly property string fragmentSource: "
                #version 440

                layout(location = 0) in vec2 qt_TexCoord0;
                layout(location = 0) out vec4 fragColor;

                layout(std140, binding = 0) uniform buf {
                    mat4 qt_Matrix;
                    float qt_Opacity;
                    vec2 fullSize;
                    float radius;
                    float edgeThickness;
                    float distortionDepth;
                    float distortionStrength;
                    float chromaticShiftPx;
                    float fresnelStrength;
                    float specularStrength;
                    float glassOpacity;
                    float liquidDepth;
                    float centerOpacity;
                    vec4 tintColor;
                    float tintAlpha;
                    float brightness;
                    float contrast;
                    float saturation;
                    float vibrancy;
                    float vibrancyDarkness;
                    float adaptiveDim;
                    float adaptiveBoost;
                    float roundingPower;
                    float padX;
                    float padY;
                    float hasBackdrop;
                };
                layout(binding = 1) uniform sampler2D source;

                // Card UV -> stretched-backdrop UV (the card occupies the center)
                vec2 toImageUV(vec2 uv) {
                    return uv * vec2(1.0 - 2.0 * padX, 1.0 - 2.0 * padY) + vec2(padX, padY);
                }

                vec4 sampleBackdrop(vec2 uv) {
                    vec2 iuv = toImageUV(uv);
                    return texture(source, clamp(iuv, vec2(0.0), vec2(1.0)));
                }

                float lpNorm(vec2 v, float p) {
                    return pow(pow(abs(v.x), p) + pow(abs(v.y), p), 1.0 / p);
                }

                float getRoundedBoxSDF(vec2 uv, float r) {
                    vec2 p = (uv - 0.5) * fullSize;
                    vec2 halfSize = fullSize * 0.5;
                    float clampedR = min(r, min(halfSize.x, halfSize.y));
                    vec2 q = abs(p) - halfSize + clampedR;
                    return min(max(q.x, q.y), 0.0) + lpNorm(max(q, 0.0), roundingPower) - clampedR;
                }

                void main() {
                    vec2 uv = qt_TexCoord0;

                    float cornerSdf = getRoundedBoxSDF(uv, radius);
                    if (cornerSdf > 0.0) discard;

                    float cornerAlpha = 1.0 - smoothstep(-1.5, 0.5, cornerSdf);
                    if (cornerAlpha < 0.001) discard;

                    float minDim = min(fullSize.x, fullSize.y);
                    float bezelWidthPx = edgeThickness * minDim;
                    if (bezelWidthPx < 0.5) bezelWidthPx = 0.5;

                // Edge zone: 1.0 at the boundary, smooth S-curve to 0.0 at
                // two bezel widths inside (drives specular/fresnel/shadow).
                float edgeProximity = smoothstep(2.0, 0.0, -cornerSdf / bezelWidthPx);

                // ---- Liquid-glass dome (ShojiWM liquid-glass.frag port) ----
                // Rounded-box SDF -> domed lens: samples are pulled inward near
                // the boundary (a magnification ring), and R/B are shifted at
                // the edge for chromatic fringing — the iOS liquid-glass look.
                float sdfScale = max(max(fullSize.x, fullSize.y), 1.0);
                float minDim2 = max(min(fullSize.x, fullSize.y), 1.0);
                float inversedSDF = max(-cornerSdf, 0.0) * sdfScale / minDim2;

                vec2 glassCoord = (uv - 0.5) * fullSize;
                float glassLen = max(max(abs(glassCoord.x), abs(glassCoord.y)), 0.0001);
                vec2 normGlass = (glassCoord / glassLen) / max(length(glassCoord / glassLen), 0.0001);

                float distFromCenter = 1.0 - clamp(inversedSDF / max(distortionDepth, 0.0001), 0.0, 1.0);
                float domeDistortion = 1.0 - sqrt(max(1.0 - distFromCenter * distFromCenter, 0.0));
                vec2 domeOffset = domeDistortion * normGlass * fullSize * 0.5 * distortionStrength;
                vec2 glassSampleUV = uv - domeOffset / fullSize;

                float domeEdge = smoothstep(0.0, 0.02, inversedSDF);
                vec2 chromaticShiftUV = normGlass * domeEdge * chromaticShiftPx / fullSize;

                // ---- Just liquid glass ----
                // The body stays transparent: the desktop shows through the
                // middle (low centerOpacity), while the liquid material — dome
                // refraction, chromatic fringing, sheen — lives in an edge ring
                // (`liquidDepth` wide). No frosted slab is painted on the card.
                vec3 backCol;
                if (hasBackdrop > 0.5) {
                    backCol.r = sampleBackdrop(glassSampleUV - chromaticShiftUV).r;
                    backCol.g = sampleBackdrop(glassSampleUV).g;
                    backCol.b = sampleBackdrop(glassSampleUV + chromaticShiftUV).b;
                    // Light glass tint for edge contrast — the center stays
                    // transparent so the live desktop shows through.
                    backCol = mix(backCol, vec3(0.04, 0.05, 0.08), 0.15);
                } else {
                    backCol = vec3(0.08, 0.09, 0.12);
                }
                // Edge fade: 0 in the middle (transparent body), 1 at the
                // boundary — the liquid ring fades in over `liquidDepth`.
                float edgeFade = 1.0 - smoothstep(0.0, liquidDepth, max(-cornerSdf, 0.0) / minDim);
                vec3 color = backCol;

                    // ---- Frosted tone mapping (hyprglass order) ----
                    float blurredLum = dot(color, vec3(0.2126, 0.7152, 0.0722));

                    // Desaturation
                    color = mix(vec3(blurredLum), color, saturation);

                    // Tight smoothstep maps the blur-compressed luminance to the
                    // full [0,1] adaptive range.
                    float lumCurve = smoothstep(0.25, 0.55, blurredLum);

                    // Adaptive dim: multiplicative (darkens bright areas)
                    color *= brightness * (1.0 - adaptiveDim * lumCurve);
                    // Adaptive boost: additive (brightens near-black areas)
                    color += vec3(adaptiveBoost * (1.0 - lumCurve) * 0.5);

                    // Contrast (pivot around midpoint)
                    color = mix(vec3(0.5), color, contrast);

                    // Vibrancy (selective saturation boost scaled by saturation)
                    float currentLum = dot(color, vec3(0.2126, 0.7152, 0.0722));
                    float sat = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
                    float darkFactor = 1.0 - vibrancyDarkness * (1.0 - blurredLum);
                    color = mix(vec3(currentLum), color, 1.0 + vibrancy * sat * darkFactor);

                    // ---- Color tint overlay ----
                    color = mix(color, tintColor.rgb, tintAlpha);

                    // ---- Fresnel rim glow ----
                    if (fresnelStrength > 0.001) {
                        float fresnel = edgeProximity * edgeProximity * fresnelStrength * 0.35;
                        color += vec3(1.0) * fresnel;
                    }

                    // ---- Specular top highlight ----
                    if (specularStrength > 0.001) {
                        float topBias = pow(max(1.0 - uv.y, 0.0), 2.0);
                        float spec = topBias * edgeProximity * edgeProximity * specularStrength * 0.30;
                        color += vec3(1.0, 0.99, 0.97) * spec;
                    }

                    // ---- Inner shadow (bottom rim) ----
                    {
                        float bottomBias = pow(uv.y, 2.0);
                        float shadow = bottomBias * edgeProximity * edgeProximity * 0.12;
                        color *= 1.0 - shadow;
                    }

                    float glassA = glassOpacity * cornerAlpha * mix(centerOpacity, 1.0, edgeFade) * qt_Opacity;
                    fragColor = vec4(color * glassA, glassA);
                }
            "

            Component.onCompleted: {
                fragmentShader = ShaderBuilder.buildFragmentShader(fragmentSource);
                if (status === ShaderEffect.Error) {
                    console.warn("[LiquidCard] glass shader failed: " + log);
                }
            }
        }

        // Blurred art backdrop — stretched beyond the card so edge refraction
        // can pull in content from beyond the boundary. Only consumed by the
        // shader; hidden from direct painting via hideSource.
        Image {
            id: artBackdrop
            anchors.fill: parent
            anchors.margins: -liquidGlass._margin
            source: root.artUrl ? root.artUrl : ""
            cache: false
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            visible: status === Image.Ready
            layer.enabled: false
        }

        ShaderEffectSource {
            id: backdropSource
            sourceItem: artBackdrop
            hideSource: true
            live: true
            smooth: true
            sourceRect: artBackdrop.visible ? Qt.rect(0, 0, artBackdrop.width, artBackdrop.height) : Qt.rect(0, 0, 0, 0)
        }

        // Diagonal sheen — matches the top-bar Glass
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            height: parent.height * 0.75
            width: parent.width * 2.4
            opacity: 0.7
            visible: (root.hovered ? root.sheenStrengthHover : root.sheenStrength) > 0
            transform: Rotation { origin.x: 0; origin.y: 0; angle: -22 }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0.30 * (root.hovered ? root.sheenStrengthHover : root.sheenStrength)); Behavior on color { ColorAnimation { duration: 200 } } }
                GradientStop { position: 0.34; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.09 * (root.hovered ? root.sheenStrengthHover : root.sheenStrength)); Behavior on color { ColorAnimation { duration: 200 } } }
                GradientStop { position: 0.72; color: Qt.rgba(1, 1, 1, 0) }
            }
        }

        // Slow drifting reflection — a soft band sweeping across the glass
        Rectangle {
            id: drift
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.45
            x: -width
            visible: root.driftEnabled
            opacity: 1.0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }

            SequentialAnimation on x {
                running: root.driftEnabled && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: root.width * 1.5; duration: 10000; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 4000 }
                NumberAnimation { to: -root.width * 0.7; duration: 10000; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 6000 }
            }
        }

        // Film grain — procedural speckle drawn once per resize (cheap, subtle)
        Canvas {
            id: noiseTile
            anchors.fill: parent
            opacity: root.noiseOpacity * 0.08
            visible: root.noiseOpacity > 0
            antialiasing: false
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var w = width, h = height;
                var n = Math.round(w * h / 24);
                for (var i = 0; i < n; i++) {
                    var v = 0.3 + Math.random() * 0.7;
                    ctx.fillStyle = Qt.rgba(v, v, v, 0.14);
                    var s = 1 + Math.random() * 1.4;
                    ctx.fillRect(Math.random() * w, Math.random() * h, s, s);
                }
            }
        }

        // Hairline edge
        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1.0, 1.0, 1.0, root.hovered ? 0.35 : (root.borderOpacity > 0 ? root.borderOpacity : 0.18))
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        // Content (clipped to the rounded card)
        Item {
            id: contentSlot
            anchors.fill: parent
        }
    }

    // ---- Card silhouette mask (only used when invertedCorners is set) ----
    Canvas {
        id: silhouette
        anchors.fill: parent
        z: -1
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function has(corner) {
            return root.invertedCorners.split(" ").indexOf(corner) !== -1;
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var w = width, h = height;
            var r = Math.max(1, root.cornerRadius);
            var ir = Math.max(1, root.invertedRadius);

            ctx.beginPath();
            ctx.moveTo(0, r);

            // Top-left (normal)
            ctx.quadraticCurveTo(0, 0, r, 0);

            // Top edge → top-right
            if (silhouette.has("topRight")) {
                ctx.lineTo(w - ir, 0);
                ctx.arc(w, 0, ir, Math.PI, Math.PI / 2, true);
            } else {
                ctx.lineTo(w - r, 0);
                ctx.quadraticCurveTo(w, 0, w, r);
            }

            // Right edge → bottom-right
            if (silhouette.has("bottomRight")) {
                ctx.lineTo(w, h - ir);
                ctx.arc(w, h, ir, -Math.PI / 2, -Math.PI, true);
            } else {
                ctx.lineTo(w, h - r);
                ctx.quadraticCurveTo(w, h, w - r, h);
            }

            // Bottom edge → bottom-left
            if (silhouette.has("bottomLeft")) {
                ctx.lineTo(ir, h);
                ctx.arc(0, h, ir, 0, -Math.PI / 2, true);
            } else {
                ctx.lineTo(r, h);
                ctx.quadraticCurveTo(0, h, 0, h - r);
            }

            // Left edge → top-left
            if (silhouette.has("topLeft")) {
                ctx.lineTo(0, ir);
                ctx.arc(0, 0, ir, Math.PI / 2, 0, true);
            } else {
                ctx.lineTo(0, r);
                ctx.quadraticCurveTo(0, 0, r, 0);
            }

            ctx.closePath();
            ctx.fillStyle = "#ffffff";
            ctx.fill();
        }
    }
}
