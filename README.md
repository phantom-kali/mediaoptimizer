# mediaoptimizer

## Dependancy Installation 
```
sudo dnf install imagemagick jpegoptim optipng ffmpeg
```

``` Usage
# Single file
./mo.sh image.jpg

# Directory (recursive)
./mo.sh -r ./images

# High quality + WebP conversion
./mo.sh -q 90 --webp -r ./media

# Video with custom settings
./mo.sh -c 20 --preset slow video.mp4
```
