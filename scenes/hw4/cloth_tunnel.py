import numpy as np
from scenes.hw4.geometry import make_cloth_grid

def make_scene():
    # Five alternating spheres
    radius = 0.95
    spheres = np.array([
        [-1.00, 8.00, 0.0, radius],
        [ 1.00, 5.90, 0.0, radius],
        [-1.00, 3.80, 0.0, radius],
        [ 1.00, 1.70, 0.0, radius],
        [-1.00, -0.40, 0.0, radius],
    ], dtype=np.float32)

    # Cloth above the first sphere
    nx, ny = 31, 25
    sx, sy = 1.0, 0.80
    positions, triangles, dx, dy = make_cloth_grid(
        nx, ny, sx, sy, orientation='horizontal')
    # Center cloth around z=0
    positions[:, 2] += sy / 2
    positions[:, 0] -= 0.20
    positions[:, 1] = 9.20

    # Structural, shear, and bending springs
    edges = []
    rest_lengths = []
    for y in range(ny):
        for x in range(nx):
            i = y * nx + x
            for ox, oy in [
                (1, 0), (0, 1),
                (1, 1), (-1, 1),
                (2, 0), (0, 2)
            ]:
                xx, yy = x + ox, y + oy
                if 0 <= xx < nx and 0 <= yy < ny:
                    edges.append((i, yy * nx + xx))
                    rest_lengths.append(
                        np.hypot(ox * dx, oy * dy))

    velocities = np.zeros_like(positions)

    return {
        'positions': positions,
        'velocities': velocities,
        'inv_masses': np.ones(
            len(positions), dtype=np.float32),
        'constraint_edges': np.array(
            edges, dtype=np.uint32),
        'rest_lengths': np.array(
            rest_lengths, dtype=np.float32),
        'triangles': triangles,
        'cloth_grid_size': (nx, ny),
        'spacing': (dx, dy),

        'planes': np.array([
            [0, 1, 0, -1.65],
        ], dtype=np.float32),
        'spheres': spheres,

        'collision_distance': 0.02,
        'contact_margin': 0.05,
        'static_friction': 0.15,
        'kinetic_friction': 0.10,

        'substeps': 8,
        'iterations': 16,

        'cam_pos': (8.0, 5.0, -8.0),
        'cam_target': (0.0, 3.0, 0.0),
        'cam_up': (0.0, 1.0, 0.0),
    }
