import slangpy as spy
import time

class App:
    def __init__(self, device, image):
        self.device = device
        self.window = spy.Window(
            width=image.width,
            height=image.height,
            title="Balboa",
            resizable=False,
        )
        self.surface = self.device.create_surface(self.window)
        self.surface.configure(
            width=self.window.width,
            height=self.window.height,
            vsync=True,
        )
        self.image = image

    def run(self, vars, render, update=None):
        start_time = time.perf_counter()

        while not self.window.should_close():
            self.window.process_events()

            next_image = self.surface.acquire_next_image()
            if not next_image:
                continue

            if update is not None:
                t = time.perf_counter() - start_time
                frame_vars = update(t, vars)
            else:
                frame_vars = vars

            command_encoder = self.device.create_command_encoder()
            render(command_encoder, frame_vars, self.image)
            command_encoder.blit(next_image, self.image)

            self.device.submit_command_buffer(
                command_encoder.finish()
            )

            del next_image
            self.surface.present()