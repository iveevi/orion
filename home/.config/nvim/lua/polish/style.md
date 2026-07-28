# Voice reference

The excerpts below are human-written, peer-reviewed prose by the author and his
collaborators and advisors. They define the target register: declarative,
precise, technical, willing to run long when the argument needs it, and free of
rhetorical padding.

Match their register, sentence rhythm, and level of hedging. Do not borrow their
topic or vocabulary. The text you are editing is probably about something else.

## Motivating a gap in prior work

From Glow Discharge (Sivaram, Ramamoorthi, Li; SIGGRAPH 2025).

Previous research in material models for surface and volume scattering has
enabled highly realistic scenes in modern rendering systems. However, there has
been comparatively little study of light sources in computer graphics despite
their critical importance in illuminating and bringing life into these scenes. In
the real world, photons are emitted through numerous physical processes including
combustion, incandescence, and fluorescence. The qualities of light produced in
each of these processes are unique to their physics, making them interesting to
study individually.

## Stating a tension, then the contribution

From Halide (Ragan-Kelley, Barnes, Adams, Paris, Durand, Amarasinghe; PLDI 2013).

Image processing pipelines combine the challenges of stencil computations and
stream programs. They are composed of large graphs of different stencil stages, as
well as complex reductions, and stages with global or data-dependent access
patterns. Because of their complex structure, the performance difference between a
naive implementation of a pipeline and an optimized one is often an order of
magnitude. Efficient implementations require optimization of both parallelism and
locality, but due to the nature of stencils, there is a fundamental tension
between parallelism, locality, and introducing redundant recomputation of shared
values. We present a systematic model of the tradeoff space fundamental to stencil
pipelines, a schedule representation which describes concrete points in this space
for each stage, and an optimizing compiler that synthesizes high performance
implementations from an algorithm and a schedule.

## Announcing the approach

From Glow Discharge (Sivaram, Ramamoorthi, Li; SIGGRAPH 2025).

It is challenging to approximate these processes using existing primitives. We are
motivated by this limitation and aim to tackle unique emissive phenomena from
their physics-based foundations. In this work, we present a model for glow
discharge that simulates the dynamics of subatomic and molecular particle
densities that arise from this specific kind of electrical discharge. The
primitives in our model can be constructed from a set of coefficients describing
the properties of these dynamics and a vector field indicating the general flow of
electrons.

## Taking a position against the status quo

From Exo 2 (Ikarashi, Bernstein, Ragan-Kelley et al.; CGO 2025).

Current scheduling languages are designed to give programmers exactly the control
they want, while automating all other concerns. However, there is no universal
answer for what performance-conscious programmers want to control, how they want
to control it, and what they want to automate, even in relatively narrow domains.
We claim that scheduling languages should, instead, be designed to grow. By
composing a set of trusted, fine-grained primitives, users can safely write their
own scheduling library to build up desired automation.

## Enumerating difficulties in order

From Taichi (Hu, Li, Durand, Ragan-Kelley et al.; SIGGRAPH Asia 2019).

Writing high-performance code for these data structures is a daunting task due to
their irregularity. Accessing their active elements in parallel imposes several
engineering challenges. First, naively traversing the hierarchy can take one or
two orders of magnitude more clock cycles than the essential computation. This is
especially troublesome for spatially coherent accesses, since common access paths
in the hierarchical data structure are traversed redundantly. Second, we need to
ensure load-balancing for efficient parallelization. Third, we need to allocate
memory and maintain sparsity when accessing inactive elements.

## Classifying prior work

From Automatic Sampling for Discontinuities (Belhe, Mehta, Chang, Georgiev, Gharbi, Ramamoorthi, Li; TOG 2025).

Previous work in boundary derivative computation can be classified into two
approaches: boundary sampling and area sampling. Boundary sampling methods achieve
high accuracy with fewer samples but are limited by their requirement for
specialized sampling routines. In contrast, area sampling methods offer greater
generality in the functions they can differentiate, but require higher sampling
rates to do so. Our method eliminates the need for specialized routines while
maintaining the efficiency of boundary sampling.

## Identifying the core technical obstacle

From Neural Geometry Fields for Meshes (Sivaram, Li, Ramamoorthi; SIGGRAPH 2024).

The primary challenge with representing meshes with neural graphics primitives is
that additional connectivity information must be constructed for surfaces with
different polygon schemes and topology. It is challenging to implement a gradient
descent algorithm for optimizing connectivity data, and correspondingly there has
been little previous work to our knowledge on representing meshes with neural
networks. Fortunately, previous work on geometry images unveils a regular
image-based scheme that can be used to represent discrete meshes.

## Justifying a design decision

From RCGP section 5 (Sivaram, Bangaru, Ramamoorthi, Li, Ragan-Kelley, Durand; SIGGRAPH 2026).

We therefore find that composing modules requires a mechanism that is more
flexible than composition itself. We converged on combinators, borrowed from
functional programming, which are sufficiently expressive for our needs. For
simple cases, module combinators bundle the resource contracts from the given
modules. Generally, however, the utility of combinators lies in their ability to
inspect and alter these contracts. Since combinators are the first site where the
contracts of independent modules interact, they are also the earliest site at
which we can diagnose and report cross-module errors.

## Naming a limitation of an alternative

From RCGP section 5 (Sivaram, Bangaru, Ramamoorthi, Li, Ragan-Kelley, Durand; SIGGRAPH 2026).

Correct command recording respects a partial ordering among commands, since some
directives cannot be sent until a specific other directive has been provided. This
idea parallels typestate analysis, which can be applied to command buffer
recording by parameterizing the command buffer type by its current state. However,
while typestates can reliably enforce correctness in command recording, they
impose restrictions that hinder modular use. As pipeline complexity scales, the
typestate dimensionality increases, and state prescriptions become lengthier.
Consequently, the benefits of writing modular code are drastically reduced.

## Describing a method concretely

From Neural Geometry Fields for Meshes (Sivaram, Li, Ramamoorthi; SIGGRAPH 2024).

Each patch is parametrized easily by construction, which allows us to attach a
trainable feature field on the patches. We then feed the features to an MLP which
outputs the displacement of the patch. To obtain a traditional mesh from our
representation for both training and actual uses, we sample vertices from each
patch and construct triangles within each patch. We then use an appearance-based
loss to optimize for the patch vertices, the MLP weights, and the features.

## Explaining background physics or mechanism

From Glow Discharge (Sivaram, Ramamoorthi, Li; SIGGRAPH 2025).

Under normal circumstances, electrons flow through conducting materials such as
metal electrodes. However, when there exists sufficient electric field strength in
an area, it can cause a dielectric breakdown, where the dielectric medium between
electrodes becomes ionized. In such a state, the medium acts as a conductor,
permitting the flow of charge. This is referred to as electrical discharge, which
comes in many forms depending on the voltage, current, and the medium.
