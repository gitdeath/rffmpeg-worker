Designed to be used with my jellyfin container as a scalable solution for ffmpeg.


Test commands: 

/usr/lib/jellyfin-ffmpeg/ffmpeg -init_hw_device opencl=ocl -filter_hw_device ocl -f lavfi -i nullsrc=s=1920x1080,format=nv12 -vf hwupload,format=opencl -vframes 2000 -f null -
