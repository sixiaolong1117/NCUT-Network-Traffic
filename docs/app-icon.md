# App 图标

以用户提供的北方工业大学校徽为参考，保留紫红色、山形和圆日元素，配合下载 / 上传箭头表示校园网流量。采用 macOS 27 Liquid Glass 风格的圆角玻璃底板、折射高光和分层质感。

这是个人非官方 App 的衍生图标，并非学校官方校徽。

- 生成方式：内置 `image_gen`，先生成，再清理外部透明区域；使用 `sips` 导出各尺寸。
- 主图：`../NCUT Network Traffic/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`（1024 × 1024，RGBA PNG）。
- 集成：沿用项目的 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`；提供 macOS 16、32、128、256、512 pt 的 1× / 2× 图标。
- 材质效果绘制在 PNG 内，不是 Icon Composer 的动态分层 `.icon` 文件。
- 设计参考：[Apple App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)。

## 初始提示词

```text
Use case: logo-brand.
Asset type: production macOS 27 app icon for "NCUT Network Traffic", a North China University of Technology campus network data allowance menu-bar utility.
Input image 1 is brand reference ONLY: use the university's dark wine-magenta color (approximately #861B54) and its recognizable abstract white mountain / triangular ribbon and small sun motif in the circular seal at the LEFT of the reference. Do not include the calligraphy, university name, seal lettering or color swatches.
Create ONE beautifully resolved square 1024x1024 macOS app icon, straight-on orthographic view, no presentation mockup. A softly rounded continuous-corner squircle occupies about 86% of the canvas, optically centered with generous TRANSPARENT margins. The tile is warm pearl-white translucent glass with a fine beveled perimeter, soft lavender and wine-magenta internal light, subtly darkened edges, bright restrained specular highlights. Inside it floats a large deep wine-magenta translucent glass medallion, containing a clean faithful simplified white NCUT angular mountain/ribbon emblem with its small white sun above-left. The circle is a gentle glass disc, NOT a text-heavy academic seal. The mountain should be strong, geometric and recognizable at small sizes.
In the LOWER part of the tile, slightly overlapping the lower edge of the medallion, place a single compact pair of bold rounded opposing vertical arrows, downward on the left and upward on the right, in luminous pearl-white glass with subtle wine-magenta edge shading. The arrows symbolize network download and upload. Keep a clear hierarchy: university mountain is the dominant mark, two data-flow arrows are secondary. Integrate them into one balanced composition with plenty of breathing room.
Style: meticulous Apple system app icon craftsmanship, refined macOS 27 Liquid Glass, layered translucent materials with physical depth, subtle refraction, crisp silhouettes and elegant controlled lighting from top-left. Premium restrained utility icon. No rainbow, no busy background, no heavy drop shadow, no chrome, no neon, no random ornament. No text, no letters, no numbers, no watermark. Transparent background OUTSIDE the rounded-square icon; the tile itself remains clearly visible pearl white. Output the actual icon asset alone.
```

## 清理提示词

```text
Use case: precise-object-edit.
Edit this completed macOS NCUT Network Traffic app icon. Preserve the existing mountain emblem, wine-magenta medallion, two white upload/download arrows, pearl glass tile, composition and premium material styling exactly.
Change only the outer transparency cleanup: remove ALL stray white speckles, magenta debris, dots, disconnected pixels, fragments, rough cutout edges and stray reflections outside the rounded-square tile. Produce a perfectly clean alpha silhouette around the smoothly antialiased squircle. The outside must be truly fully transparent, with no colored noise, no opaque background and no checkerboard. Add a little more transparent breathing room so the tile occupies approximately 84% of the square canvas with equal margins. Render the entire icon centered on a square transparent canvas. Keep every interior design detail unchanged. No new shapes, no text, no watermark. Deliver the actual clean production icon alone.
```
