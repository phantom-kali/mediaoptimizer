# mediaoptimizer

## Dependancy Installation 
```
sudo dnf install imagemagick jpegoptim optipng ffmpeg
```

``` Usage
# Single file
./optimize-web-media.sh image.jpg

# Directory (recursive)
./optimize-web-media.sh -r ./images

# High quality + WebP conversion
./optimize-web-media.sh -q 90 --webp -r ./media

# Video with custom settings
./optimize-web-media.sh -c 20 --preset slow video.mp4
```
