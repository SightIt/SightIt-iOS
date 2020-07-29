# SightIt
SightIt is a mobile application that aids blind or visually impaired users to find and localize common objects by leveraging the power of Computer Vision and Augmented Reality. (Microsoft Hackathon 2020)

## Our story
Some of our team members have worked on assistive technology for people with disabilities and wanted to improve existing apps and services. SightIt was inspired by Seeing AI, which is a remarkably useful app for people who are blind or visually impaired. We want to be that inspirational by pursuing a project that could be meaningful to other people while learning new technology we're passionate about.

## What it does
SightIt enables a blind or visually impaired (B/VI) user to locate common objects using their phone. The user can speak to the phone through a voice interface to request the app to find an object in their surroundings. After receiving the request, the app will scan the area and analyze the captured video stream from the user's phone. If an object is detected in the video frame, the app will mark the 2D pixel coordinate of the object and project it into a 3D spatial coordinate. The app will then guide the user towards the located object by telling them where the object is relative to the phone and by producing haptic feedback whenever the user is pointing their phone towards the object.

## How we built it
The project has 3 main parts:

1. **Accessible interface:** the app needs to be accessible to B/VI users. This requires the app to be usable via a few simple voice commands. The visual interface of the app also needs to be intuitive and user-friendly for sighted people who could be friends or family members of B/VI users.

2. **Computer vision:** the app needs to has the ability to recognize and localize one common object in a video stream. This involves a pre-trained machine learning model on the cloud to which the app will feed the video data for 2D object localization tasks. To achieve this, we utilized the Custom Vision service on Azure. We created our own dataset and trained a model to detect common kitchen objects. Right now, our minimum viable product (MVP) will be able to detect and localize 5 items: cup, plate, fork, knife, and spoon.

3. **Augmented reality:** the app has to project the 2D localization result into a 3D spatial coordinate. It also needs to keep track of this 3D coordinate consistently in real-time. By leveraging AR technology, most smartphones has the capability to achieve this task. Our iOS MVP is able to track the location of a static object in real time.

## What's next
We'd like to continue improving the MVP and bring this product to the B/VI communities for user testing. Right now, the app is able to detect only a small set of objects and will not allow users to recognize custom objects of their own. Therefore, possible next steps could be expanding the list of common objects and adding the capacity for users to train their own items. Furthermore, users might want to detect multiple objects at once and track their dynamic locations in real time. This use case is technologically challenging, and we might want to talk to users and explore their needs to clearly define this feature.

## Credit
This project is based off of an open-source project, [ObjectLocator](https://github.com/occamLab/ObjectLocator).
