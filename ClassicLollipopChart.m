
classdef ClassicLollipopChart < handle
    % CLASSICLOLLIPOPCHART  Classic (non-interactive) lollipop/dumbbell chart.
    %
    % Usage:
    %   obj = ClassicLollipopChart(T, 'XVar', 'Name', 'YVars', {'A','B'}, ...)
    %
    % The constructor forwards options used by LollipopManager:
    %   MarkerSize, Colors, OffsetFrac, ShowDelta, Baseline
    properties
        Manager  % LollipopManager instance
    end

    methods
        function obj = ClassicLollipopChart(T, varargin)
            if ~istable(T)
                error('ClassicLollipopChart:BadInput', 'First input must be a table.');
            end

            % Parse minimal expected name-values; allow flexible YVars types
            p = inputParser;
            addParameter(p, 'XVar', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'YVars', {}, @(x) iscell(x) || isstring(x) || ischar(x));
            addParameter(p, 'MarkerSize', [], @(x) isempty(x) || isnumeric(x));
            addParameter(p, 'Colors', [], @(x) isempty(x) || isnumeric(x));
            addParameter(p, 'OffsetFrac', 0.02, @isnumeric);
            addParameter(p, 'ShowDelta', true, @islogical);
            addParameter(p, 'Baseline', 0, @isnumeric);
            parse(p, varargin{:});

            XVar = char(p.Results.XVar);
            YVars = p.Results.YVars;
            if isstring(YVars), YVars = cellstr(YVars); end
            if ischar(YVars), YVars = {YVars}; end

            if isempty(XVar) || isempty(YVars)
                error('ClassicLollipopChart:MissingVars', 'You must provide ''XVar'' and ''YVars'' name-value pairs.');
            end

            opts = struct();
            if ~isempty(p.Results.MarkerSize), opts.MarkerSize = p.Results.MarkerSize; end
            if ~isempty(p.Results.Colors), opts.Colors = p.Results.Colors; end
            opts.OffsetFrac = p.Results.OffsetFrac;
            opts.ShowDelta = p.Results.ShowDelta;
            opts.Baseline = p.Results.Baseline;

            mgr = LollipopManager(T, XVar, cellstr(YVars), opts);
            mgr.draw();

            obj.Manager = mgr;
        end
    end
end