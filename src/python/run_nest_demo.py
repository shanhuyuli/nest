"""Driver entry point for nest animation."""
import sys
from nest_animation import run_animation

if __name__ == '__main__':
    save_path = sys.argv[1] if len(sys.argv) > 1 else None
    run_animation(save_path)
