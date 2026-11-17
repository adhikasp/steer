---
rule: youtube-transcript
when: The user pasted a YouTube/video link, or asks what a video says or shows.
threshold: 0.6
---
Pull the transcript first (`yt-dlp` subtitles or the transcript API), summarise from the text, and only then open frames if the question is visual. Never answer from the title, the description, or memory, and never claim to have watched something that was only skimmed.
