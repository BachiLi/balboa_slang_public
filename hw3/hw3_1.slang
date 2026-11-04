
import hw3_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  StructuredBuffer<Sphere> spheres,
                  uniform int num_spheres,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    // Calculate the aspect ratio
    float aspect = float(width) / float(height);

    // Calculate the pixel center on the image plane
    float x = (2.0 * (float(tid.x) + 0.5) / float(width) - 1.0) * aspect;
    float y = 1.0 - 2.0 * (float(tid.y) + 0.5) / float(height);

    // Camera origin and ray direction
    float3 ray_origin = float3(0.0, 0.0, 0.0);
    float3 ray_dir = normalize(float3(x, y, -1.0));

    // Initialize closest intersection
    float closest_t = 1e30;
    float3 hit_normal = float3(0.0);
    bool hit = false;

    // Check intersection with every sphere
    for (int i = 0; i < num_spheres; i++) {
        Sphere sphere = spheres[i];

        float3 oc = ray_origin - sphere.center;

        // Coefficients of the quadratic equation
        float a = dot(ray_dir, ray_dir);
        float b = 2.0 * dot(ray_dir, oc);
        float c = dot(oc, oc) - sphere.radius * sphere.radius;

        float2 roots;

        if (solve_quadratic(a, b, c, roots)) {

            // Check both intersection points
            for (int j = 0; j < 2; j++) {
                float t = roots[j];

                // Only accept positive intersections
                if (t > 0.0 && t < closest_t) {
                    closest_t = t;

                    // Calculate intersection point
                    float3 hit_point = ray_origin + t * ray_dir;

                    // Calculate sphere normal
                    hit_normal = normalize(hit_point - sphere.center);

                    hit = true;
                }
            }
        }
    }

    // Visualize the normal if we hit a sphere
    if (hit) {
        float3 color = (hit_normal + 1.0) / 2.0;
        image[tid] = float4(color, 1.0);
    }
    else {
        // Otherwise use background color
        image[tid] = float4(background, 1.0);
    }
}
