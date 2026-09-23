import argparse
import hw1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument('-width', type=int, default=640)
    parser.add_argument('-height', type=int, default=480)
    parser.add_argument("-output", type=str)
    subparsers = parser.add_subparsers(dest="hw", required=True)
    # HW 1.1
    p = subparsers.add_parser("1_1")
    p.add_argument('-center', type=float, nargs=2, default=[320, 240])
    p.add_argument('-radius', type=float, default=100)
    p.add_argument('-color', type=float, nargs=3, default=[1.0, 0.5, 0.5])
    p.set_defaults(func=hw1.hw1_1)
    # HW 1.2
    p = subparsers.add_parser("1_2")
    p.add_argument('-points', type=float, nargs='+', required=True)
    p.add_argument('--closed', action="store_true")
    p.add_argument('-fill_color', type=float, nargs=3)
    p.add_argument('-stroke_color', type=float, nargs=3)
    p.add_argument('-stroke_width', type=float, default=1.0)
    p.set_defaults(func=hw1.hw1_2)
    # HW 1.3
    p = subparsers.add_parser("1_3")
    p.add_argument('scene')
    p.set_defaults(func=hw1.hw1_3)
    # HW 1.4
    p = subparsers.add_parser("1_4")
    p.add_argument('scene')
    p.set_defaults(func=hw1.hw1_4)
    # HW 1.5
    p = subparsers.add_parser("1_5")
    p.add_argument('scene')
    p.add_argument('-time', type=float, default=0)
    p.set_defaults(func=hw1.hw1_5)
    # HW 1.6
    p = subparsers.add_parser("1_6")
    p.add_argument('scene')
    p.set_defaults(func=hw1.hw1_6)
    # HW 1.7
    p = subparsers.add_parser("1_7")
    p.add_argument('scene')
    p.set_defaults(func=hw1.hw1_7)
    # HW 1.8
    p = subparsers.add_parser("1_8")
    p.add_argument('scene')
    p.set_defaults(func=hw1.hw1_8)

    args = parser.parse_args()
    args.func(args)
