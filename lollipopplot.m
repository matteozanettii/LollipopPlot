function varargout = lollipopplot(T, varargin)
% LOLLIPOPPLOT  Factory wrapper that constructs and returns chart objects.
%   OBJ = LOLLIPOPPLOT(T, ...)          -> returns InteractiveLollipopChart (backwards compatible)
%   [I, C] = LOLLIPOPPLOT(T, ...)       -> returns InteractiveLollipopChart I and ClassicLollipopChart C
%
% Recognized name-value (optional): 'XVar', 'YVars' (forwarded to Classic). Any other NV pairs
% are forwarded to both constructors.

    if nargin < 1 || ~istable(T)
        error('lollipopplot:BadInput', 'First input must be a table.');
    end

    % Parse XVar and YVars if provided; leave the rest in varargin for forwarding
    p = inputParser;
    addParameter(p, 'XVar', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'YVars', {}, @(x) iscell(x) || isstring(x) || ischar(x));
    % parse only known parameters from varargin (ignores others)
    try
        parse(p, varargin{:});
    catch
        % if parse fails (unknown types), treat as not provided
        p.Results.XVar = '';
        p.Results.YVars = {};
    end
    XVar_in = char(p.Results.XVar);
    YVars_in = p.Results.YVars;
    if isstring(YVars_in), YVars_in = cellstr(YVars_in); end
    if ischar(YVars_in), YVars_in = {YVars_in}; end

    % Construct interactive chart (existing behavior)
    I = InteractiveLollipopChart(T, varargin{:});

    % Determine whether to construct Classic chart:
    buildClassic = true;
    % If user provided both, use them
    if ~isempty(XVar_in) && ~isempty(YVars_in)
        XVar = XVar_in;
        YVars = cellstr(YVars_in);
    else
        % Try to infer sensible defaults from table
        varNames = T.Properties.VariableNames;
        nVars = numel(varNames);

        % find numeric variables for Y
        isNum = false(1,nVars);
        for k = 1:nVars
            col = T.(varNames{k});
            isNum(k) = isnumeric(col) && isvector(col);
        end
        numIdx = find(isNum);

        % Infer XVar: prefer first non-numeric (categorical/string/datetime) else first variable
        XVar = '';
        for k = 1:nVars
            col = T.(varNames{k});
            if iscategorical(col) || isstring(col) || iscellstr(col) || isdatetime(col)
                XVar = varNames{k};
                break;
            end
        end
        if isempty(XVar)
            XVar = varNames{1};
        end

        % Infer YVars: pick up to two numeric variables (or one if only one)
        if isempty(numIdx)
            YVars = {};
        else
            % prefer numeric vars that are not chosen as XVar
            numNames = varNames(numIdx);
            numNames(strcmp(numNames,XVar)) = [];
            if isempty(numNames)
                % if removed XVar left no numeric, fallback to any numeric including XVar
                numNames = varNames(numIdx);
            end
            YVars = numNames(1:min(2,numel(numNames)));
            YVars = cellstr(YVars);
        end
    end

    % If no YVars could be determined, skip building Classic and warn
    if isempty(YVars)
        buildClassic = false;
        warning('lollipopplot:NoYVars', 'Could not determine numeric YVars for Classic chart. Only interactive chart created.');
    end

    C = [];
    if buildClassic
        % Forward the relevant name-value pairs plus remaining varargin
        % Build argument list ensuring XVar and YVars are included
        nv = varargin;
        % remove any existing XVar/YVars entries in nv (simple pass: rebuild)
        % Compose new NV list
        nvNew = [{'XVar', XVar, 'YVars', YVars}, nv];
        % Construct classic chart
        C = ClassicLollipopChart(T, nvNew{:});
    end

    % Return based on number of requested outputs
    switch nargout
        case 0
            % none
        case 1
            varargout{1} = I;
        case 2
            varargout{1} = I;
            varargout{2} = C;
        otherwise
            error('lollipopplot:TooManyOutputs', 'Request at most two outputs: [Interactive, Classic].');
    end
end
