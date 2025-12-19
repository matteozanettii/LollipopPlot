function obj = lollipopplot(T, varargin)
% LOLLIPOPPLOT  Factory wrapper that constructs and returns the chart object.
%   OBJ = LOLLIPOPPLOT(T, ...) constructs and returns an
%   InteractiveLollipopChart object. Accepts same name-value
%   parameters as the class constructor.
    if nargin < 1
        error('lollipopplot:NoTable', 'You must supply a table as the first input.');
    end
    obj = InteractiveLollipopChart(T, varargin{:});
end

function obj = createLollipopChart(T, varargin)
% CREATELOLLIPOPCHART  Backwards-compatible alias for lollipopplot.
%   OBJ = CREATELOLLIPOPCHART(...) calls lollipopplot and returns the object.
    obj = lollipopplot(T, varargin{:});
end
