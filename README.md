# SysModels

This is a Julia package for creating Systems Models.

It requires Julia 0.5 or 0.6.

You can install it from the julia shell:

```julia
julia> Pkg.clone("https://github.com/tristanc/SysModels.git")
```

There are some small examples in the test/ directory, and some larger ones,
based on the code used in some of the papers below, in the examples/ folder.

Better documentation will be coming soon.

The code was written for modelling aspects of organizational security, and the
package currently reflects this.  Eventually, the goal is to move the
security-specific code into its own SecModels package, leaving the generic systems
modelling code here.

The code was written as part of the
[Productive Security](http://www.riscs.org.uk/?page_id=15) project, and was
used in several publications:



* Tristan Caulfield and Simon Parkin. Case study: predicting the impact of a physical access control intervention. In _STAST: 6th International Workshop on Socio-Technical Aspects in Security and Trust, 2016_.

* Tristan Caulfield, Michelle Baddeley, and David Pym. Social learning in systems security modelling. In _Social Simulation Conference 2016_.

* Tristan Caulfield and David Pym. Improving security policy decisions with models. _Security & Privacy, IEEE_, 13(5):34–41, Sept 2015. doi:10.1109/MSP.2015.97.

* Tristan Caulfield and David Pym. Modelling and simulating systems security policy. In _Proceedings of the 8th International Conference on Simulation Tools and Techniques_, SIMUTools '15, 9–18. ICST, Brussels, Belgium, Belgium, 2015. ICST (Institute for Computer Sciences, Social-Informatics and Telecommunications Engineering). doi:10.4108/eai.24-8-2015.2260765.

* Tristan Caulfield, David Pym, and Julian Williams. Compositional security modelling. In Theo Tryfonas and Ioannis Askoxylakis, editors, _Human Aspects of Information Security, Privacy, and Trust_, volume 8533 of Lecture Notes in Computer Science, pages 233–245. Springer International Publishing, 2014. doi:10.1007/978-3-319-07620-1_21.
