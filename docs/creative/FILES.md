# Creative library

Start with the [unified creative direction](README.md), which aligns the cats with the current Roblox MOBA. The earlier briefs below preserve the original exploration; when they differ, the unified direction and current game code take precedence.

## Art and previews

- [Art direction](assets/art-direction.png)
- [Character sheet](assets/character-study.png)
- [Options storyboard](assets/options-storyboard.png)
- [Options animatic, with scratch voices](assets/options-animatic-v1.mp4)
- [Original art prompt](assets/art-generation-prompt.txt)
- [Character/storyboard prompts](assets/production-image-prompts.txt)

## Writing and research archive

- [Original brand and NFT research brief](archive/meo-meo-meo-creative-brief.md)
- [Production pack: scripts, timing, voices and collectible studies](archive/production-pack-01.md)
- [Animatic review and technical verification notes](archive/animatic-review.md)

The archive includes historical assumptions about the project and its financial concept. Refer to [current pairing status](../robinhood-chain-pairing.md) for the repo integration assessment. Original references to an `animatic-work` folder now correspond to the production source folder below.

## Production sources

- [Options subtitle draft](production/episode-01-options.srt)
- [Content experiment tracker](production/experiment-log.csv)
- [Animatic rebuild script](production/animatic/build_animatic.py)
- [Styled caption reference](production/animatic/captions.ass)
- Scratch voice stems: [MEO](production/animatic/meo.aiff), [ME](production/animatic/me.aiff), [MO](production/animatic/mo.aiff)

To rebuild the timing preview, install Python 3 and FFmpeg/ffprobe with libass support, then run from the repository root:

```sh
python3 docs/creative/production/animatic/build_animatic.py
```

The script uses the committed storyboard and voice stems, embeds the caption timing, and writes intermediate clips, verification data and a rebuilt video under `production/animatic/renders/`. It does not overwrite the approved preview. Fonts may render differently on other systems. The original system voices are temporary performances, and the video uses static storyboard frames rather than final character animation.

Generated render caches are reproducible and ignored by Git. The source art, writing, audio, captions, prompts and finished preview are committed here.
