import argparse
from glob import glob
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('-x', default=0, type=int)
parser.add_argument('-y', default=0, type=int)
parser.add_argument('dir')
parser.add_argument('out_file')
parser.add_argument('in_w', type=int)
parser.add_argument('in_h', type=int)
parser.add_argument('out_w', default=0, type=int)
parser.add_argument('out_h', default=0, type=int)
args = parser.parse_args()
resize = True
if args.out_h <= 0 and args.out_w <= 0:
  args.out_h = args.in_h
  args.out_w = args.in_w
  resize = False
elif args.out_h <= 0:
  args.out_h = round(args.out_w * (args.in_h / args.in_w))
elif args.out_w <= 0:
  args.out_w = round(args.out_h * (args.in_w / args.in_h))

xywh_to_lurl = lambda x, y, w, h: (x, y, w + x, h + y)
files = sorted(glob(f'{args.dir}/*.png'))
print(f'({args.x}, {args.y}, {args.in_w}, {args.in_h}) -> ({args.out_w}, {args.out_h})*{len(files)}')
out = Image.new('RGBA', (args.out_w * len(files), args.out_h))
for i, f in enumerate(files):
  im = Image.open(f)
  # resize each band individually to fix alpha issues
  bands = [
    band.resize(
      size=(args.out_w, args.out_h),
      resample=Image.Resampling.HAMMING,
      box=xywh_to_lurl(args.x, args.y, args.in_w, args.in_h)
    )
    for band in im.split()
  ]
  im = Image.merge(im.mode, bands)
  out.paste(im, box=xywh_to_lurl(i * args.out_w, 0, args.out_w, args.out_h))

out.save(args.out_file)