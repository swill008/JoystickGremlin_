# Remaining Path B wiring (apply after pull)

These six edits finish listener start/stop, profile XML, options, and DILL-safe labels.

## 1. `gremlin/code_runner.py`

After `from gremlin.input_refresh import RefreshPhysicalInputs` add:

```
from gremlin.osc import OscRuntime
```

After `sendinput.MouseController().start()` add:

```
            OscRuntime().start()
```

At the start of the "Stop all manager classes" block add:

```
        OscRuntime().stop()
```

## 2. `joystick_gremlin.py`

With the other gremlin imports add:

```
import gremlin.osc
```

At the end of `shutdown_cleanup()` add:

```
    gremlin.osc.OscRuntime().stop()
```

At the end of `register_config_options()` add enabled/host/port:

```
    cfg.register(
        "global", "osc", "enabled",
        PropertyType.Bool, True,
        "Listen for OSC packets while a profile is active.",
        {}, True,
    )
    cfg.register(
        "global", "osc", "host",
        PropertyType.String, "127.0.0.1",
        "IP address the OSC listener binds to. Use 0.0.0.0 to accept LAN packets.",
        {}, True,
    )
    cfg.register(
        "global", "osc", "port",
        PropertyType.Int, 9000,
        "UDP port for incoming OSC (Companion Stream Deck default for Path B).",
        {"min": 1, "max": 65535}, True,
    )
```

## 3. `gremlin/profile.py`

```
from gremlin.osc import OscDevice
```

In `Profile.__init__` after `LogicalDevice().reset()`:

```
        OscDevice().reset()
```

In `from_xml` after logical devices:

```
        self._osc_devices_from_xml(root)
```

In `to_xml` after logical devices:

```
        root.append(self._osc_devices_to_xml())
```

After `_logical_devices_to_xml` add:

```
    def _osc_devices_from_xml(self, root_node: ElementTree.Element) -> None:
        osc = OscDevice()
        for node in root_node.findall("./osc-device/input"):
            osc.create(
                input_type=read_subelement(node, "input-type"),
                input_id=read_subelement(node, "input-id"),
                label=read_subelement(node, "label"),
            )

    def _osc_devices_to_xml(self) -> ElementTree.Element:
        node = ElementTree.Element("osc-device")
        for label in OscDevice().labels_of_type():
            item = OscDevice()[label]
            input_node = ElementTree.Element("input")
            input_node.append(create_subelement_node("input-type", item.type))
            input_node.append(create_subelement_node("input-id", item.id))
            input_node.append(create_subelement_node("label", item.label))
            node.append(input_node)
        return node
```

## 4. `gremlin/ui/device.py`

Import `OSC_DEVICE_UUID`. In `InputIdentifier.label` treat that GUID like Logical Device (`dev_name = "OSC"`). In `linear_index`, if GUID is OSC return `max(int(self.input_id) - 1, 0)` before calling DILL.

## 5. `gremlin/event_handler.py`

In `Event.display_name`, if `str(self.device_guid) == "a7c3e91b-4d2f-4e18-9b06-2f8c1d5a6e70"` use label `"OSC"` and skip the missing-device warning.

## 6. `gremlin/ui/osc_device_model.py`

`OscInputIdentifier.label` should use `OscDevice().find_by_id(...)` so the mapping pane shows `/streamdeck/1`.
