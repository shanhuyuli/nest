import sys; from nest_animation import run_animation
if __name__ == '__main__': run_animation(sys.argv[1] if len(sys.argv)>1 else None)
