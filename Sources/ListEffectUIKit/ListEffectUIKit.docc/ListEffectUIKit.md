# ``ListEffectUIKit``

Apply IListEffect's shared effect model to table views and collection views.

## Overview

`ListEffectUIKit` provides three integrations: one-shot cell entrances through ``ListEffectEntrance``, scroll-linked transforms through ``PositionEffectDriver``, and inertial collection-view motion through ``SpringyCollectionLayout``.

The scroll-view drivers are lazily retained by associated objects and do not replace the host's delegate or data source.

## Topics

### Entrance Effects

- ``ListEffectEntrance``
- ``UIKit/UIScrollView/entrance``
- <doc:DrivingEntranceEffects>

### Position Effects

- ``PositionEffectDriver``
- ``UIKit/UIScrollView/scrollEffect``
- <doc:DrivingPositionEffects>

### Springy Collection Layout

- ``SpringyCollectionLayout``
- <doc:UsingSpringyCollectionLayout>
