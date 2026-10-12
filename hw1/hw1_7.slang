import hw1_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int samples_per_axis,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Circle> circles,
                  StructuredBuffer<Polyline> polylines,
                  StructuredBuffer<QuadraticBezier> /*quadratic_beziers*/, // ignore for now
                  StructuredBuffer<float2> points,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    image[tid] = float4(1.0);
    // TODO: your code here
    
    // Accumulate subpixel colors
    float3 rgb_sum = float3(0.0);

    for (int a = 0; a < samples_per_axis; a++)
    {
        for (int b = 0; b < samples_per_axis; b++)
        {
            // Compute sample position
            float2 sample_pos = float2(0.0, 0.0);

            sample_pos.x = tid.x + (a + 0.5) / samples_per_axis;
            sample_pos.y = float(height) - (tid.y + (b + 0.5) / samples_per_axis);

            float3 color = float3(0.0);
            float remaining = 1.0;

            // Process shapes from front to back
            for (int i = 0; i < num_shapes; i++)
            {
                Shape shape = shapes[i];

                bool is_inside_stroke = false;
                bool is_inside_fill = false;

                // Convert to object coordinates
                float3 sample_h = float3(sample_pos, 1.0);
                float3 transformed_pos = mul(shape.world_to_obj, sample_h);
                float2 object_pos = transformed_pos.xy;

                // Circle detection
                if (shape.type == 0)
                {
                    Circle currentCircle = circles[shape.index];

                    float dist = distance(object_pos, currentCircle.center);

                    if (dist < currentCircle.radius && shape.use_fill)
                    {
                        is_inside_fill = true;
                    }

                    if (dist >= currentCircle.radius - shape.stroke_width / 2.0 && dist <= currentCircle.radius + shape.stroke_width / 2.0 && shape.use_stroke)
                    {
                        is_inside_stroke = true;
                    }
                }

                // Polyline detection
                else if (shape.type == 1)
                {
                    Polyline currentPolyline = polylines[shape.index];

                    int num_points = currentPolyline.pts_end - currentPolyline.pts_begin;
                    int num_segments;

                    if (currentPolyline.closed)
                    {
                        num_segments = num_points;
                    }
                    else
                    {
                        num_segments = num_points - 1;
                    }

                    int intersections = 0;

                    if (num_points > 0)
                    {
                        for (int j = 0; j < num_segments; j++)
                        {
                            float2 p0 = points[currentPolyline.pts_begin + j];
                            float2 p1 = points[currentPolyline.pts_begin + ((j + 1) % num_points)];

                            // Find closest point on segment
                            float2 segment = p1 - p0;
                            float2 to_sample = object_pos - p0;

                            float numerator = dot(to_sample, segment);
                            float denominator = dot(segment, segment);

                            float dist_to_segment;

                            if (denominator > 0.0)
                            {
                                float t = numerator / denominator;
                                t = clamp(t, 0.0, 1.0);

                                float2 closest_point = p0 + t * segment;

                                dist_to_segment = distance(object_pos, closest_point);
                            }
                            else
                            {
                                dist_to_segment = distance(object_pos, p0);
                            }

                            // Detect stroke coverage
                            if (shape.use_stroke && dist_to_segment <= shape.stroke_width / 2.0)
                            {
                                is_inside_stroke = true;
                            }

                            // Ray casting for polygon fill
                            if (currentPolyline.closed && shape.use_fill)
                            {
                                if ((object_pos.y >= p0.y && object_pos.y < p1.y) || (object_pos.y >= p1.y && object_pos.y < p0.y))
                                {
                                    float t = (object_pos.y - p0.y) / (p1.y - p0.y);
                                    float x_intersection = p0.x + t * (p1.x - p0.x);

                                    if (x_intersection > object_pos.x)
                                    {
                                        intersections++;
                                    }
                                }
                            }
                        }
                    }

                    // Apply even-odd rule for fill
                    if (shape.use_fill && currentPolyline.closed && intersections % 2 == 1)
                    {
                        is_inside_fill = true;
                    }
                }

                // Stroke alpha blending
                if (is_inside_stroke)
                {
                    color += remaining * shape.stroke_rgba.a * shape.stroke_rgba.rgb;
                    remaining *= 1.0 - shape.stroke_rgba.a;
                }

                // Fill alpha blending
                if (is_inside_fill)
                {
                    color += remaining * shape.fill_rgba.a * shape.fill_rgba.rgb;
                    remaining *= 1.0 - shape.fill_rgba.a;
                }

                if (remaining <= 0.0)
                {
                    break;
                }
            }

            // Blend background
            color += remaining * background.rgb;

            // Accumulate subpixel color
            rgb_sum += color;
        }
    }

    // Average subpixel colors
    int num_subpixels = samples_per_axis * samples_per_axis;
    float3 final_color = rgb_sum / num_subpixels;

    // Write final pixel
    image[tid] = float4(final_color, 1.0);

}
